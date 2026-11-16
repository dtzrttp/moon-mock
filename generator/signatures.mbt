///|
pub suberror GenerationError {
  GenerationError(String)
} derive(Debug)

///|
pub extend GenerationError with Debug::{to_repr}

///|
priv struct Signature {
  name : String
  args : Array[String]
  returns : String
  error : String?
  async_ : Bool
  cannot_raise : Bool
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
fn type_text(typ : @syntax.Type, file : String) -> String raise GenerationError {
  match typ {
    Name(constr_id~, tys~, ..) => {
      let name = constructor_name(constr_id, file)
      let args = []
      for child in tys.iter() {
        args.push(type_text(child, file))
      }
      if args.is_empty() {
        name
      } else {
        name + "[" + args.join(", ") + "]"
      }
    }
    Object(constr_id) => "&" + constructor_name(constr_id, file)
    Option(ty~, ..) => type_text(ty, file) + "?"
    Tuple(tys~, ..) => {
      let args = []
      for child in tys.iter() {
        args.push(type_text(child, file))
      }
      "(" + args.join(", ") + ")"
    }
    _ => {
      unsupported(
        file,
        typ.loc(),
        "支持命名类型、类型应用、trait 对象、元组和可选类型",
      )
      ""
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
fn collect_signature(
  declared_method : @syntax.TraitMethodDecl,
  file : String,
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
    guard positional_type(param) is Some(typ) else {
      unsupported(file, param.loc(), "要求带类型的位置参数")
      continue
    }
    if index == 0 {
      guard typ
        is Name(constr_id={ id: Ident(name="Self"), .. }, tys=@list.Empty, ..) else {
        unsupported(file, param.loc(), "首个参数必须是 Self")
        continue
      }
    } else {
      args.push(type_text(typ, file))
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
  let error = match declared_method.error_type {
    @syntax.ErrorType(ty~) => Some(type_text(ty, file))
    DefaultErrorType(_) => Some("Error")
    NoErrorType if async_ => Some("Error")
    NoErrorType | Noraise(_) => None
    MaybeError(_) => {
      unsupported(file, declared_method.loc, "暂不支持条件错误效果")
      None
    }
  }
  {
    name: declared_method.name.name,
    args,
    returns,
    error,
    async_,
    cannot_raise: async_ && error is None,
  }
}

///|
fn collect(
  source : String,
  name : String,
  file : String,
) -> Array[Signature] raise GenerationError {
  let (decls, errors) = @parser.parse_string(
    source,
    name=file,
    parser=Handrolled,
  )
  if !errors.is_empty() {
    let details = errors.map(report => {
      let at = report.loc.start
      "\{file}:\{at.lnum}:\{at.column()}: parse_error: \{report.msg}"
    })
    raise GenerationError(details.join("\n"))
  }
  let mut chosen : @syntax.TraitDecl? = None
  for entry in decls.iter() {
    if entry is @syntax.TopTrait(decl) && decl.name.name == name {
      if chosen is Some(_) {
        raise GenerationError(file + ": ambiguous_trait: " + name)
      }
      chosen = Some(decl)
    }
  }
  guard chosen is Some(decl) else {
    raise GenerationError(file + ": trait_not_found: " + name)
  }
  if !(decl.supers is @list.Empty) ||
    !(decl.attrs is @list.Empty) ||
    decl.is_declare ||
    decl.methods is @list.Empty {
    unsupported(
      file,
      decl.loc,
      "暂不支持超 trait、声明、属性或空 trait",
    )
  }
  let signatures = []
  let seen : Map[String, Bool] = Map([])
  for declared_method in decl.methods.iter() {
    if seen.contains(declared_method.name.name) {
      unsupported(
        file,
        declared_method.loc,
        "同一 trait 中的方法名重复",
      )
    }
    seen[declared_method.name.name] = true
    signatures.push(collect_signature(declared_method, file))
  }
  signatures
}
