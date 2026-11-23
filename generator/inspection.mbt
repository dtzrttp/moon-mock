///|
/// 源文件中一条 trait 方法声明的信息。
/// 位置为声明起始处，行和列从 1 开始。
pub struct MethodInfo {
  name : String
  line : Int32
  column : Int32
  async_ : Bool
  /// 源码是否带有默认实现标记 = _。
  has_default : Bool
  /// 语法中声明的参数数目，包含 Self 接收者。
  parameter_count : Int32
} derive(ToJson, Debug)

///|
pub extend MethodInfo with Debug::{to_repr}

///|
pub extend MethodInfo with ToJson::{to_json}

///|
/// 源文件中一条 trait 声明的信息。
/// 父 trait 和直接声明的方法均保持源码顺序，位置为声明起始处。
pub struct TraitInfo {
  name : String
  file : String
  line : Int32
  column : Int32
  parents : Array[String]
  methods : Array[MethodInfo]
} derive(ToJson, Debug)

///|
pub extend TraitInfo with Debug::{to_repr}

///|
pub extend TraitInfo with ToJson::{to_json}

///|
fn read_method_info(declared : @syntax.TraitMethodDecl) -> MethodInfo {
  let at = declared.loc.start
  {
    name: declared.name.name,
    line: at.lnum,
    column: at.column(),
    async_: declared.is_async is Some(_),
    has_default: declared.has_default is Some(_),
    parameter_count: declared.params.length(),
  }
}

///|
fn read_trait_info(source : TraitSource) -> TraitInfo {
  let { filename, declaration, } = source
  let at = declaration.loc.start
  let parents = []
  for parent in declaration.supers.iter() {
    parents.push(
      match parent.trait_ {
        Ident(name~) => name
        Dot(pkg~, id~) => "@\{pkg}.\{id}"
      },
    )
  }
  let methods = []
  for declared in declaration.methods.iter() {
    methods.push(read_method_info(declared))
  }
  {
    name: declaration.name.name,
    file: filename,
    line: at.lnum,
    column: at.column(),
    parents,
    methods,
  }
}

///|
/// 按源码顺序列出 trait 声明，保留重名声明与限定的父 trait 名。
/// 只读取语法树，父 trait 解析、类型检查和生成可行性由后续步骤处理。
/// 若源文件存在语法错误，返回解析器报告的诊断。
pub fn inspect_source(
  source : String,
  filename~ : String = "<stdin>",
) -> Array[TraitInfo] raise GenerationError {
  match try_inspect_source(source, filename~) {
    Ok(traits) => traits
    Err(diagnostics) => raise legacy_error(diagnostics)
  }
}

///|
/// 检查一个源文件，保留解析器的各条语法诊断及其位置。
pub fn try_inspect_source(
  source : String,
  filename~ : String = "<stdin>",
) -> Result[Array[TraitInfo], Array[GenerationDiagnostic]] {
  Ok(parse_traits(source, filename).map(read_trait_info)) catch {
    GenerationFailure(diagnostics) => Err(diagnostics)
  }
}
