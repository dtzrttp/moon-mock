///|
/// 生成失败的文本诊断，供已有调用者匹配和呈现。
pub suberror GenerationError {
  GenerationError(String)
} derive(Debug)

///|
pub extend GenerationError with Debug::{to_repr}

///|
/// 由生成器在出错处构造的诊断。
/// 行和列从 1 开始，文件级错误的行和列为 None。
pub struct GenerationDiagnostic {
  code : String
  message : String
  filename : String
  line : Int32?
  column : Int32?
} derive(ToJson, Debug)

///|
pub extend GenerationDiagnostic with Debug::{to_repr}

///|
pub extend GenerationDiagnostic with ToJson::{to_json}

///|
/// 渲染为可直接展示的文本，保留文件名中的所有字符。
pub fn GenerationDiagnostic::text(self : GenerationDiagnostic) -> String {
  let label = match (self.line, self.column) {
    (Some(line), Some(column)) => "\{self.filename}:\{line}:\{column}"
    _ => self.filename
  }
  "\{label}: \{self.code}: \{self.message}"
}

///|
priv suberror GenerationFailure {
  GenerationFailure(Array[GenerationDiagnostic])
}

///|
fn format_diagnostics(diagnostics : Array[GenerationDiagnostic]) -> String {
  diagnostics.map(GenerationDiagnostic::text).join("\n")
}

///|
fn legacy_error(diagnostics : Array[GenerationDiagnostic]) -> GenerationError {
  GenerationError(format_diagnostics(diagnostics))
}

///|
priv struct SourceSite {
  filename : String
  at : @basic.Position?
}

///|
fn SourceSite::new(filename : String, at? : @basic.Position) -> SourceSite {
  { filename, at, }
}

///|
fn SourceSite::text(self : SourceSite) -> String {
  match self.at {
    Some(at) => "\{self.filename}:\{at.lnum}:\{at.column()}"
    None => self.filename
  }
}

///|
fn SourceSite::diagnostic(
  self : SourceSite,
  code : String,
  message : String,
) -> GenerationDiagnostic {
  {
    code,
    message,
    filename: self.filename,
    line: self.at.map(at => at.lnum),
    column: self.at.map(@basic.Position::column),
  }
}

///|
fn[T] SourceSite::reject(
  self : SourceSite,
  code : String,
  message : String,
) -> T raise GenerationFailure {
  raise GenerationFailure([self.diagnostic(code, message)])
}
