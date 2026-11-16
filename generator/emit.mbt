///|
fn Signature::arg_type(self : Signature) -> String {
  match self.args.length() {
    0 => "Unit"
    1 => self.args[0].value_type
    _ => "(" + self.args.map(arg => arg.value_type).join(", ") + ")"
  }
}

///|
fn Signature::effect(self : Signature) -> String {
  match self.error {
    Some(error) => " raise " + error
    None if self.cannot_raise => " noraise"
    None => ""
  }
}

///|
fn Signature::action_type(self : Signature) -> String {
  let prefix = if self.async_ { "async " } else { "" }
  prefix + "(" + self.arg_type() + ") -> " + self.returns + self.effect()
}

///|
fn positional_name(base : String, labels : Array[String]) -> String {
  let mut name = base
  while labels.contains(name) {
    name += "_"
  }
  name
}

///|
fn emit_method(
  out : StringBuilder,
  mock : String,
  trait_name : String,
  shape : Signature,
) -> Unit {
  let name = shape.name
  let slot = "slot_" + name
  let matcher = "@mock_runtime.Matcher[" + shape.arg_type() + "]"
  let opts = "times~ : Int32 = 1, sequence? : @mock_runtime.Sequence"
  let invoke = "self." + slot + ".expect"
  out.write_string(
    "\n///|\n#warnings(\"-unused_value\")\nfn \{mock}::expect_\{name}(self : \{mock}, matcher : \{matcher}, value : \{shape.returns}, \{opts}) -> Unit {\n\{invoke}(matcher, _ => value, times~, sequence?)\n}\n",
  )
  out.write_string(
    "\n///|\n#warnings(\"-unused_value\")\nfn \{mock}::respond_\{name}(self : \{mock}, matcher : \{matcher}, action : \{shape.action_type()}, \{opts}) -> Unit {\n\{invoke}(matcher, action, times~, sequence?)\n}\n",
  )
  if shape.error is Some(error) {
    out.write_string(
      "\n///|\n#warnings(\"-unused_value\")\nfn \{mock}::raise_\{name}(self : \{mock}, matcher : \{matcher}, error : \{error}, \{opts}) -> Unit {\n\{invoke}(matcher, _ => raise error, times~, sequence?)\n}\n",
    )
  }
  let labels = shape.args.filter_map(arg => arg.label)
  let receiver = positional_name("self", labels)
  let params = [receiver]
  let values = []
  for i, arg in shape.args {
    match arg.label {
      Some(label) => {
        params.push(label + (if arg.optional { "?" } else { "~" }))
        values.push(label)
      }
      None => {
        let binding = positional_name("arg_" + i.to_string(), labels)
        params.push(binding)
        values.push(binding)
      }
    }
  }
  let args = match values.length() {
    0 => "()"
    1 => values[0]
    _ => "(" + values.join(", ") + ")"
  }
  out.write_string(
    "\n///|\nimpl \{trait_name} for \{mock} with fn \{name}(\{params.join(", ")}) {\n  let args = \{args}\n  let action = \{receiver}.\{slot}.take(args)\n  action(args)\n}\n",
  )
}

///|
fn valid_type_name(name : String) -> Bool {
  let mut first = true
  for char in name {
    let upper = 'A' <= char && char <= 'Z'
    let lower = 'a' <= char && char <= 'z'
    let digit = '0' <= char && char <= '9'
    if (first && !upper) ||
      (!first && !(upper || lower || digit || char == '_')) {
      return false
    }
    first = false
  }
  !first
}

///|
/// 生成同包白盒测试使用的 MoonBit 源码。
pub fn generate(
  source : String,
  trait_name : String,
  filename~ : String = "<stdin>",
  mock_name? : String,
) -> String raise GenerationError {
  let mock = mock_name.unwrap_or("Mock" + trait_name)
  if mock_name is Some(_) && !valid_type_name(mock) {
    raise GenerationError(
      filename + ": invalid_mock_name: 生成类型名应以大写字母开头",
    )
  }
  let signatures = collect(source, trait_name, filename)
  let out = StringBuilder()
  out.write_string(
    "// 由 moon-mock 生成，请从原 trait 重新生成。\n\n",
  )
  out.write_string("///|\nstruct \{mock} {\n")
  for shape in signatures {
    out.write_string(
      "  slot_\{shape.name} : @mock_runtime.Method[\{shape.arg_type()}, \{shape.action_type()}]\n",
    )
  }
  out.write_string(
    "}\n\n///|\n#warnings(\"-unused_value\")\nfn \{mock}::new(c : @mock_runtime.Controller) -> \{mock} {\n{\n",
  )
  for shape in signatures {
    out.write_string(
      "  slot_\{shape.name}: @mock_runtime.Method::new(c, \"\{trait_name}.\{shape.name}\"),\n",
    )
  }
  out.write_string("}\n}\n")
  for shape in signatures {
    emit_method(out, mock, trait_name, shape)
  }
  let generated = out.to_string()
  let (_, errors) = @parser.parse_string(generated, parser=Handrolled)
  if !errors.is_empty() {
    raise GenerationError(
      "emitter_error: " + errors.map(report => report.msg).join("; "),
    )
  }
  let formatted = @sourcefmt.format(generated, block_line=true)
    .trim()
    .to_owned()
  formatted
  .replace_all(old="重新生成。\n///|", new="重新生成。\n\n///|")
  .replace_all(old="times? : Int32 = 1,", new="times~ : Int32 = 1,")
  .replace_all(old="=> raise  error", new="=> raise error") +
  "\n"
}
