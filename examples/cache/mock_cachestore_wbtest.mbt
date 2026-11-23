// 由 moon-mock 生成，请从原 trait 重新生成。

///|
struct MockCacheStore {
  slot_get : @mock_runtime.Method[String, (String) -> String? raise CacheError]
  slot_put : @mock_runtime.Method[
    (String, String, Int32),
    ((String, String, Int32)) -> Unit raise CacheError,
  ]
}

///|
#warnings("-unused_value")
fn MockCacheStore::new(c : @mock_runtime.Controller) -> MockCacheStore {
  {
    slot_get: @mock_runtime.Method::new(c, "CacheStore.get"),
    slot_put: @mock_runtime.Method::new(c, "CacheStore.put"),
  }
}

///|
#warnings("-unused_value")
fn MockCacheStore::expect_get(
  self : MockCacheStore,
  matcher : @mock_runtime.Matcher[String],
  value : String?,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_get.expect(matcher, _ => value, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockCacheStore::respond_get(
  self : MockCacheStore,
  matcher : @mock_runtime.Matcher[String],
  action : (String) -> String? raise CacheError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_get.expect(matcher, action, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockCacheStore::raise_get(
  self : MockCacheStore,
  matcher : @mock_runtime.Matcher[String],
  error : CacheError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_get.expect(matcher, _ => raise error, times~, sequence?, count?)
}

///|
impl CacheStore for MockCacheStore with fn get(self, arg_0) {
  let args = arg_0
  let action = self.slot_get.take(args)
  action(args)
}

///|
#warnings("-unused_value")
fn MockCacheStore::expect_put(
  self : MockCacheStore,
  matcher : @mock_runtime.Matcher[(String, String, Int32)],
  value : Unit,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_put.expect(matcher, _ => value, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockCacheStore::respond_put(
  self : MockCacheStore,
  matcher : @mock_runtime.Matcher[(String, String, Int32)],
  action : ((String, String, Int32)) -> Unit raise CacheError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_put.expect(matcher, action, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockCacheStore::raise_put(
  self : MockCacheStore,
  matcher : @mock_runtime.Matcher[(String, String, Int32)],
  error : CacheError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_put.expect(matcher, _ => raise error, times~, sequence?, count?)
}

///|
impl CacheStore for MockCacheStore with fn put(self, arg_0, arg_1, ttl~) {
  let args = (arg_0, arg_1, ttl)
  let action = self.slot_put.take(args)
  action(args)
}
