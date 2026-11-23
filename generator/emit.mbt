///|
fn Signature::arg_type(self : Signature) -> String {
  match self.args.length() {
    0 => "Unit"
    1 => self.args[0].value_type
    _ => "(" + self.args.map(arg => arg.value_type).join(", ") + ")"
  }
}

///|
fn Signature::action_type(self : Signature) -> String {
  function_type_text(self.arg_type(), self.returns, self.error, self.async_)
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
fn emit_method(out : StringBuilder, mock : String, shape : Signature) -> Unit {
  let trait_name = shape.owner
  let name = shape.name
  let slot = "slot_" + name
  let matcher = "@mock_runtime.Matcher[" + shape.arg_type() + "]"
  let opts = "times~ : Int32 = 1, sequence? : @mock_runtime.Sequence, count? : @mock_runtime.CallCount"
  let invoke = "self." + slot + ".expect"
  out.write_string(
    "\n///|\n#warnings(\"-unused_value\")\nfn \{mock}::expect_\{name}(self : \{mock}, matcher : \{matcher}, value : \{shape.returns}, \{opts}) -> Unit {\n\{invoke}(matcher, _ => value, times~, sequence?, count?)\n}\n",
  )
  out.write_string(
    "\n///|\n#warnings(\"-unused_value\")\nfn \{mock}::respond_\{name}(self : \{mock}, matcher : \{matcher}, action : \{shape.action_type()}, \{opts}) -> Unit {\n\{invoke}(matcher, action, times~, sequence?, count?)\n}\n",
  )
  if shape.error is Some(error) {
    out.write_string(
      "\n///|\n#warnings(\"-unused_value\")\nfn \{mock}::raise_\{name}(self : \{mock}, matcher : \{matcher}, error : \{error}, \{opts}) -> Unit {\n\{invoke}(matcher, _ => raise error, times~, sequence?, count?)\n}\n",
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
fn mock_type_name(trait_name : String, mock_name : String?) -> String {
  mock_name.unwrap_or("Mock" + trait_name)
}

///|
fn checked_mock_name(
  trait_name : String,
  mock_name : String?,
  filename : String,
) -> String raise GenerationFailure {
  let mock = mock_type_name(trait_name, mock_name)
  if mock_name is Some(_) && !valid_type_name(mock) {
    return SourceSite::new(filename).reject(
      "invalid_mock_name", "生成类型名应以大写字母开头",
    )
  }
  mock
}

///|
/// 生成同包白盒测试使用的 MoonBit 源码。
/// 辅助源码按（文件名，源码）传入，可用于解析同包的超 trait。
pub fn generate(
  source : String,
  trait_name : String,
  filename~ : String = "<stdin>",
  mock_name? : String,
  additional_sources~ : Array[(String, String)] = [],
) -> String raise GenerationError {
  generate_source(source, trait_name, filename, mock_name, additional_sources) catch {
    GenerationFailure(diagnostics) => raise legacy_error(diagnostics)
  }
}

///|
/// 生成源码并以结构化形式返回诊断。解析器可以报告多条语法错误。
/// 用法和生成规则与 generate 相同。
pub fn try_generate(
  source : String,
  trait_name : String,
  filename~ : String = "<stdin>",
  mock_name? : String,
  additional_sources~ : Array[(String, String)] = [],
) -> Result[String, Array[GenerationDiagnostic]] {
  Ok(
    generate_source(source, trait_name, filename, mock_name, additional_sources),
  ) catch {
    GenerationFailure(diagnostics) => Err(diagnostics)
  }
}

///|
fn generate_source(
  source : String,
  trait_name : String,
  filename : String,
  mock_name : String?,
  additional_sources : Array[(String, String)],
) -> String raise GenerationFailure {
  let mock = checked_mock_name(trait_name, mock_name, filename)
  let prepared = prepare_source_set(
    source,
    filename,
    additional_sources,
    require_primary=trait_name,
  )
  emit_prepared(prepared, trait_name, mock)
}

///|
fn emit_prepared(
  prepared : PreparedSources,
  trait_name : String,
  mock : String,
) -> String raise GenerationFailure {
  let hierarchy = collect(prepared, trait_name)
  let out = StringBuilder()
  out.write_string(
    "// 由 moon-mock 生成，请从原 trait 重新生成。\n\n",
  )
  out.write_string("///|\nstruct \{mock} {\n")
  for shape in hierarchy.methods {
    out.write_string(
      "  slot_\{shape.name} : @mock_runtime.Method[\{shape.arg_type()}, \{shape.action_type()}]\n",
    )
  }
  out.write_string(
    "}\n\n///|\n#warnings(\"-unused_value\")\nfn \{mock}::new(c : @mock_runtime.Controller) -> \{mock} {\n{\n",
  )
  for shape in hierarchy.methods {
    out.write_string(
      "  slot_\{shape.name}: @mock_runtime.Method::new(c, \"\{shape.owner}.\{shape.name}\"),\n",
    )
  }
  out.write_string("}\n}\n")
  for shape in hierarchy.methods {
    emit_method(out, mock, shape)
  }
  for name in hierarchy.empty_traits {
    out.write_string("\n///|\nimpl \{name} for \{mock}\n")
  }
  let generated = out.to_string()
  let (_, errors) = @parser.parse_string(generated, parser=Handrolled)
  if !errors.is_empty() {
    return SourceSite::new(prepared.filename).reject(
      "emitter_error",
      errors.map(report => report.msg).join("; "),
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
