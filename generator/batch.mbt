///|
/// 单次批量生成可处理的请求数上限。
pub const MAX_BATCH_REQUESTS : Int32 = 256

///|
/// 一个独立的生成请求。辅助源码按（文件名，源码）传入。
pub(all) struct BatchRequest {
  source : String
  trait_name : String
  filename : String
  mock_name : String?
  additional_sources : Array[(String, String)]
} derive(Debug)

///|
pub extend BatchRequest with Debug::{to_repr}

///|
/// 一项批量生成的结果。序号从 0 开始。
/// 成功时 generated 有值，失败时 error 保留文本诊断。
pub(all) struct BatchResult {
  index : Int32
  trait_name : String
  filename : String
  generated : String?
  error : String?
} derive(ToJson, Debug)

///|
pub extend BatchResult with Debug::{to_repr}

///|
pub extend BatchResult with ToJson::{to_json}

///|
const MAX_CACHED_SOURCE_SETS : Int32 = 16

///|
priv struct BatchSourceKey {
  filename : String
  source : String
  additional_sources : Array[(String, String)]
} derive(Eq, Hash)

///|
/// 检查批次大小和输出类型名冲突。此操作只读取请求的元数据。
/// 无效的自定义类型名由单项生成报告。
pub fn validate_batch_requests(
  requests : Array[BatchRequest],
) -> Unit raise GenerationError {
  if requests.length() > MAX_BATCH_REQUESTS {
    raise GenerationError(
      "resource_limit: 每批最多 \{MAX_BATCH_REQUESTS} 个请求",
    )
  }
  let seen : Map[String, Int32] = Map([])
  for index, request in requests {
    let mock = mock_type_name(request.trait_name, request.mock_name)
    if request.mock_name is Some(_) && !valid_type_name(mock) {
      continue
    }
    if seen.get(mock) is Some(first) {
      let other = requests[first]
      raise GenerationError(
        "duplicate_mock_name: 类型 \{mock} 同时用于第 \{first + 1} 项（\{other.filename}）和第 \{index + 1} 项（\{request.filename}）",
      )
    }
    seen[mock] = index
  }
}

///|
/// 按输入顺序生成各项源码。批次内最多保留最近解析的 16 组主辅源码索引。
/// 拒绝超出上限或输出类型名重复的批次，其余错误保存在各项结果。
pub fn generate_batch(
  requests : Array[BatchRequest],
) -> Array[BatchResult] raise GenerationError {
  validate_batch_requests(requests)
  let cache : Map[BatchSourceKey, PreparedSources] = Map([])
  let results = []
  for index, request in requests {
    let (generated, error) = (Some(generate_batch_item(request, cache)), None) catch {
      GenerationFailure(diagnostics) =>
        (None, Some(format_diagnostics(diagnostics)))
    }
    results.push({
      index,
      trait_name: request.trait_name,
      filename: request.filename,
      generated,
      error,
    })
  }
  results
}

///|
fn generate_batch_item(
  request : BatchRequest,
  cache : Map[BatchSourceKey, PreparedSources],
) -> String raise GenerationFailure {
  let { source, trait_name, filename, mock_name, additional_sources, } = request
  let mock = checked_mock_name(trait_name, mock_name, filename)
  let key : BatchSourceKey = { filename, source, additional_sources, }
  let prepared = match cache.get(key) {
    Some(found) => found
    None => {
      let indexed = prepare_source_set(
        source,
        filename,
        additional_sources,
        require_primary=trait_name,
      )
      if cache.length() == MAX_CACHED_SOURCE_SETS &&
        cache.keys().next() is Some(oldest) {
        cache.remove(oldest)
      }
      cache[key] = indexed
      indexed
    }
  }
  emit_prepared(prepared, trait_name, mock)
}
