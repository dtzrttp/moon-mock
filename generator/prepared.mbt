///|
/// 已解析的一组源码，可用于生成主文件中的多个 trait。
/// 索引由生成器持有，每次生成独立遍历所选 trait 的继承关系。
pub struct PreparedSources {
  priv filename : String
  priv primary : Map[String, Array[TraitSource]]
  priv all_traits : Map[String, Array[TraitSource]]
}

///|
fn prepare_source_set(
  source : String,
  filename : String,
  additional_sources : Array[(String, String)],
  require_primary? : String,
) -> PreparedSources raise GenerationFailure {
  let primary : Map[String, Array[TraitSource]] = Map([])
  index_traits(primary, source, filename)
  if require_primary is Some(name) {
    locate_trait(primary, name, SourceSite::new(filename), "trait_not_found")
    |> ignore
  }
  let supplemental : Map[String, Array[TraitSource]] = Map([])
  for (extra_file, extra_source) in additional_sources {
    index_traits(supplemental, extra_source, extra_file)
  }
  if supplemental.is_empty() {
    return { filename, primary, all_traits: primary, }
  }
  let all_traits = primary.copy()
  for name, matches in supplemental {
    all_traits[name] = match primary.get(name) {
      Some(main_matches) => main_matches + matches
      None => matches
    }
  }
  { filename, primary, all_traits, }
}

///|
/// 解析主文件和辅助文件，并构造可复用的 trait 索引。
/// 辅助文件按（文件名，源码）传入。语法错误在准备阶段报告，
/// 同名声明和继承冲突在按需生成时报告。
pub fn prepare_sources(
  source : String,
  filename~ : String = "<stdin>",
  additional_sources~ : Array[(String, String)] = [],
) -> PreparedSources raise GenerationError {
  prepare_source_set(source, filename, additional_sources) catch {
    GenerationFailure(diagnostics) => raise legacy_error(diagnostics)
  }
}

///|
/// 从已准备的索引为主文件中的 trait 生成 mock 源码。
/// 辅助文件中的声明可供继承链引用。
pub fn generate_prepared(
  prepared : PreparedSources,
  trait_name : String,
  mock_name? : String,
) -> String raise GenerationError {
  try {
    let mock = checked_mock_name(trait_name, mock_name, prepared.filename)
    emit_prepared(prepared, trait_name, mock)
  } catch {
    GenerationFailure(diagnostics) => raise legacy_error(diagnostics)
  }
}
