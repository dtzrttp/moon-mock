// 由 moon-mock 生成，请从原 trait 重新生成。

///|
struct MockOrigin {
  slot_fetch : @mock_runtime.Method[
    String,
    async (String) -> String raise CacheError,
  ]
}

///|
#warnings("-unused_value")
fn MockOrigin::new(c : @mock_runtime.Controller) -> MockOrigin {
  { slot_fetch: @mock_runtime.Method::new(c, "Origin.fetch"), }
}

///|
#warnings("-unused_value")
fn MockOrigin::expect_fetch(
  self : MockOrigin,
  matcher : @mock_runtime.Matcher[String],
  value : String,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_fetch.expect(matcher, _ => value, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockOrigin::respond_fetch(
  self : MockOrigin,
  matcher : @mock_runtime.Matcher[String],
  action : async (String) -> String raise CacheError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_fetch.expect(matcher, action, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockOrigin::raise_fetch(
  self : MockOrigin,
  matcher : @mock_runtime.Matcher[String],
  error : CacheError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_fetch.expect(matcher, _ => raise error, times~, sequence?, count?)
}

///|
impl Origin for MockOrigin with fn fetch(self, arg_0) {
  let args = arg_0
  let action = self.slot_fetch.take(args)
  action(args)
}
