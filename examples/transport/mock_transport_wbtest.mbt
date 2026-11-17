// 由 moon-mock 生成，请从原 trait 重新生成。

///|
struct MockTransport {
  slot_fetch : @mock_runtime.Method[
    String,
    async (String) -> String raise TransportError,
  ]
  slot_is_ready : @mock_runtime.Method[Unit, async (Unit) -> Bool noraise]
  slot_close : @mock_runtime.Method[Unit, async (Unit) -> Unit raise Error]
}

///|
#warnings("-unused_value")
fn MockTransport::new(c : @mock_runtime.Controller) -> MockTransport {
  {
    slot_fetch: @mock_runtime.Method::new(c, "Transport.fetch"),
    slot_is_ready: @mock_runtime.Method::new(c, "Transport.is_ready"),
    slot_close: @mock_runtime.Method::new(c, "Transport.close"),
  }
}

///|
#warnings("-unused_value")
fn MockTransport::expect_fetch(
  self : MockTransport,
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
fn MockTransport::respond_fetch(
  self : MockTransport,
  matcher : @mock_runtime.Matcher[String],
  action : async (String) -> String raise TransportError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_fetch.expect(matcher, action, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockTransport::raise_fetch(
  self : MockTransport,
  matcher : @mock_runtime.Matcher[String],
  error : TransportError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_fetch.expect(matcher, _ => raise error, times~, sequence?, count?)
}

///|
impl Transport for MockTransport with fn fetch(self, arg_0) {
  let args = arg_0
  let action = self.slot_fetch.take(args)
  action(args)
}

///|
#warnings("-unused_value")
fn MockTransport::expect_is_ready(
  self : MockTransport,
  matcher : @mock_runtime.Matcher[Unit],
  value : Bool,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_is_ready.expect(matcher, _ => value, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockTransport::respond_is_ready(
  self : MockTransport,
  matcher : @mock_runtime.Matcher[Unit],
  action : async (Unit) -> Bool noraise,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_is_ready.expect(matcher, action, times~, sequence?, count?)
}

///|
impl Transport for MockTransport with fn is_ready(self) {
  let args = ()
  let action = self.slot_is_ready.take(args)
  action(args)
}

///|
#warnings("-unused_value")
fn MockTransport::expect_close(
  self : MockTransport,
  matcher : @mock_runtime.Matcher[Unit],
  value : Unit,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_close.expect(matcher, _ => value, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockTransport::respond_close(
  self : MockTransport,
  matcher : @mock_runtime.Matcher[Unit],
  action : async (Unit) -> Unit raise Error,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_close.expect(matcher, action, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockTransport::raise_close(
  self : MockTransport,
  matcher : @mock_runtime.Matcher[Unit],
  error : Error,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_close.expect(matcher, _ => raise error, times~, sequence?, count?)
}

///|
impl Transport for MockTransport with fn close(self) {
  let args = ()
  let action = self.slot_close.take(args)
  action(args)
}
