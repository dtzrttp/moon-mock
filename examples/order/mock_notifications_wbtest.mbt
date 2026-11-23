// 由 moon-mock 生成，请从原 trait 重新生成。

///|
struct MockNotifications {
  slot_publish : @mock_runtime.Method[
    PlacedOrder,
    async (PlacedOrder) -> Unit raise CheckoutError,
  ]
}

///|
#warnings("-unused_value")
fn MockNotifications::new(c : @mock_runtime.Controller) -> MockNotifications {
  { slot_publish: @mock_runtime.Method::new(c, "Notifications.publish"), }
}

///|
#warnings("-unused_value")
fn MockNotifications::expect_publish(
  self : MockNotifications,
  matcher : @mock_runtime.Matcher[PlacedOrder],
  value : Unit,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_publish.expect(matcher, _ => value, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockNotifications::respond_publish(
  self : MockNotifications,
  matcher : @mock_runtime.Matcher[PlacedOrder],
  action : async (PlacedOrder) -> Unit raise CheckoutError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_publish.expect(matcher, action, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockNotifications::raise_publish(
  self : MockNotifications,
  matcher : @mock_runtime.Matcher[PlacedOrder],
  error : CheckoutError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_publish.expect(matcher, _ => raise error, times~, sequence?, count?)
}

///|
impl Notifications for MockNotifications with fn publish(self, arg_0) {
  let args = arg_0
  let action = self.slot_publish.take(args)
  action(args)
}
