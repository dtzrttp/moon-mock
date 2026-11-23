///|
pub suberror CacheError {
  InvalidConfig(String)
  ReadUnavailable
  WriteUnavailable
  OriginUnavailable
  PayloadTooLarge
} derive(Debug)

///|
pub extend CacheError with Debug::{to_repr}

///|
/// TTL由真实缓存实现执行。本示例不读系统时间，不提供缓存持久化。
pub(all) struct CachePolicy {
  ttl_seconds : Int32
  fallback_on_read_error : Bool
  write_required : Bool
  max_payload_chars : Int32
}

///|
pub enum ValueSource {
  CacheHit
  OriginFetch
}

///|
pub(all) struct CacheWarning {
  phase : String
  cause : CacheError
}

///|
pub(all) struct LoadedValue {
  value : String
  source : ValueSource
  warnings : Array[CacheWarning]
}

///|
pub(open) trait CacheStore {
  fn get(Self, String) -> String? raise CacheError
  fn put(Self, String, String, ttl~ : Int32) -> Unit raise CacheError
}

///|
pub(open) trait Origin {
  async fn fetch(Self, String) -> String raise CacheError
}

///|
fn validate_policy(key : String, policy : CachePolicy) -> Unit raise CacheError {
  if key.trim().is_empty() {
    raise InvalidConfig("缓存键不能为空")
  }
  if policy.ttl_seconds < 1 || policy.ttl_seconds > 86400 {
    raise InvalidConfig("TTL必须在1到86400秒之间")
  }
  if policy.max_payload_chars < 0 || policy.max_payload_chars > 1048576 {
    raise InvalidConfig(
      "内容上限必须在0到1048576个Unicode标量值之间",
    )
  }
}

///|
fn check_payload(value : String, limit : Int32) -> Unit raise CacheError {
  // String迭代产生Unicode标量值，避免把UTF-16编码单位误当作字符数量。
  let mut count = 0
  for _ in value {
    count += 1
    if count > limit {
      raise PayloadTooLarge
    }
  }
}

///|
/// 缓存优先读取，未命中才回源，写入故障按显式策略处理。
/// 不提供请求合并、后台重试、网络连接或过期时间计算。
pub async fn[C : CacheStore, O : Origin] load(
  cache : C,
  origin : O,
  key : String,
  policy : CachePolicy,
) -> LoadedValue raise CacheError {
  validate_policy(key, policy)
  let warnings = []
  let cached = CacheStore::get(cache, key) catch {
    error => {
      if !policy.fallback_on_read_error {
        raise error
      }
      warnings.push({ phase: "read", cause: error, })
      None
    }
  }
  if cached is Some(value) {
    check_payload(value, policy.max_payload_chars)
    return { value, source: CacheHit, warnings, }
  }
  let value = Origin::fetch(origin, key)
  check_payload(value, policy.max_payload_chars)
  CacheStore::put(cache, key, value, ttl=policy.ttl_seconds) catch {
    error => {
      if policy.write_required {
        raise error
      }
      warnings.push({ phase: "write", cause: error, })
    }
  }
  { value, source: OriginFetch, warnings, }
}
