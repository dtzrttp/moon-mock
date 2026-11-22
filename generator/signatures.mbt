///|
pub suberror GenerationError {
  GenerationError(String)
} derive(Debug)

///|
pub extend GenerationError with Debug::{to_repr}

///|
priv struct Argument {
  value_type : String
  label : String?
  optional : Bool
}

///|
priv struct Signature {
  owner : String
  name : String
  args : Array[Argument]
  returns : String
  error : String?
  async_ : Bool
}

///|
fn unsupported(
  file : String,
  location : @basic.Location,
  reason : String,
) -> Unit raise GenerationError {
  let at = location.start
  raise GenerationError(
    "\{file}:\{at.lnum}:\{at.column()}: unsupported_signature: \{reason}",
  )
}

///|
fn constructor_name(
  constr_id : @syntax.ConstrId,
  file : String,
) -> String raise GenerationError {
  match constr_id.id {
    Ident(name="Self") => {
      unsupported(
        file,
        constr_id.loc,
        "Self 只能出现在首个接收者位置",
      )
      ""
    }
    Ident(name~) => name
    Dot(pkg~, id~) => "@" + pkg + "." + id
  }
}

///|
fn function_type_text(
  params : String,
  returns : String,
  error : String?,
  async_ : Bool,
) -> String {
  let prefix = if async_ { "async " } else { "" }
  let effect = match error {
    Some(name) => " raise " + name
    None if async_ => " noraise"
    None => ""
  }
  prefix + "(" + params + ") -> " + returns + effect
}

///|
fn type_text(
  typ : @syntax.Type,
  file : String,
  depth~ : Int32 = 0,
) -> String raise GenerationError {
  if depth > 64 {
    let at = typ.loc().start
    raise GenerationError(
      "\{file}:\{at.lnum}:\{at.column()}: resource_limit: 类型嵌套最多 64 层",
    )
  }
  match typ {
    Name(constr_id~, tys~, ..) => {
      let name = constructor_name(constr_id, file)
      let args = []
      for child in tys.iter() {
        args.push(type_text(child, file, depth=depth + 1))
      }
      if args.is_empty() {
        name
      } else {
        name + "[" + args.join(", ") + "]"
      }
    }
    Object(constr_id) => "&" + constructor_name(constr_id, file)
    Option(ty~, ..) => type_text(ty, file, depth=depth + 1) + "?"
    Tuple(tys~, ..) => {
      let args = []
      for child in tys.iter() {
        args.push(type_text(child, file, depth=depth + 1))
      }
      "(" + args.join(", ") + ")"
    }
    Arrow(args~, res~, err~, is_async~, nocancel_~, loc~) => {
      if nocancel_ is Some(at) {
        unsupported(file, at, "暂不支持 nocancel 函数类型")
      }
      let params = []
      for arg in args.iter() {
        params.push(type_text(arg, file, depth=depth + 1))
      }
      let async_ = is_async is Some(_)
      let returns = type_text(res, file, depth=depth + 1)
      let error = error_type_text(err, async_, file, loc, depth=depth + 1)
      "(" + function_type_text(params.join(", "), returns, error, async_) + ")"
    }
    _ => {
      unsupported(
        file,
        typ.loc(),
        "支持命名类型、类型应用、trait 对象、元组、可选类型和函数类型",
      )
      ""
    }
  }
}

///|
fn error_type_text(
  err : @syntax.ErrorType,
  async_ : Bool,
  file : String,
  location : @basic.Location,
  depth~ : Int32 = 0,
) -> String? raise GenerationError {
  match err {
    @syntax.ErrorType(ty~) => Some(type_text(ty, file, depth~))
    DefaultErrorType(_) => Some("Error")
    NoErrorType if async_ => Some("Error")
    NoErrorType | Noraise(_) => None
    MaybeError(_) => {
      unsupported(file, location, "暂不支持条件错误效果")
      None
    }
  }
}

///|
fn positional_type(arg : @syntax.Parameter) -> @syntax.Type? {
  match arg {
    DiscardPositional(ty~, ..) | Positional(ty~, ..) => ty
    _ => None
  }
}

///|
fn collect_argument(
  arg : @syntax.Parameter,
  file : String,
) -> Argument? raise GenerationError {
  match arg {
    DiscardPositional(ty=Some(ty), ..) | Positional(ty=Some(ty), ..) =>
      Some({ value_type: type_text(ty, file), label: None, optional: false, })
    Labelled(binder~, ty=Some(ty)) =>
      Some({
        value_type: type_text(ty, file),
        label: Some(binder.name),
        optional: false,
      })
    QuestionOptional(binder~, ty=Some(ty)) =>
      Some({
        value_type: "Option[" + type_text(ty, file) + "]",
        label: Some(binder.name),
        optional: true,
      })
    _ => {
      unsupported(
        file,
        arg.loc(),
        "要求带类型的位置参数或标签参数",
      )
      None
    }
  }
}

///|
fn collect_signature(
  declared_method : @syntax.TraitMethodDecl,
  file : String,
  owner : String,
) -> Signature raise GenerationError {
  if !(declared_method.quantifiers is @list.Empty) {
    unsupported(file, declared_method.loc, "暂不支持方法泛型")
  }
  if declared_method.nocancel_ is Some(_) {
    unsupported(file, declared_method.loc, "暂不支持 nocancel 方法")
  }
  if !(declared_method.attrs is @list.Empty) {
    unsupported(file, declared_method.loc, "暂不支持带属性的方法")
  }
  let args = []
  let mut index = 0
  for param in declared_method.params.iter() {
    if index == 0 {
      guard positional_type(param)
        is Some(
          Name(constr_id={ id: Ident(name="Self"), .. }, tys=@list.Empty, ..)
        ) else {
        unsupported(file, param.loc(), "首个参数必须是 Self")
        continue
      }
    } else if collect_argument(param, file) is Some(arg) {
      args.push(arg)
    }
    index += 1
  }
  if index == 0 {
    unsupported(file, declared_method.loc, "缺少 Self 接收者")
  }
  let returns = match declared_method.return_type {
    Some(typ) => type_text(typ, file)
    None => "Unit"
  }
  let async_ = declared_method.is_async is Some(_)
  let error = error_type_text(
    declared_method.error_type,
    async_,
    file,
    declared_method.loc,
  )
  { owner, name: declared_method.name.name, args, returns, error, async_, }
}
