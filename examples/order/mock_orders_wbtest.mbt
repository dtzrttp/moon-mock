// 由 moon-mock 生成，请从原 trait 重新生成。

///|
struct MockOrders {
  slot_save : @mock_runtime.Method[
    PlacedOrder,
    (PlacedOrder) -> Unit raise CheckoutError,
  ]
}

///|
#warnings("-unused_value")
fn MockOrders::new(c : @mock_runtime.Controller) -> MockOrders {
  { slot_save: @mock_runtime.Method::new(c, "Orders.save"), }
}

///|
#warnings("-unused_value")
fn MockOrders::expect_save(
  self : MockOrders,
  matcher : @mock_runtime.Matcher[PlacedOrder],
  value : Unit,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_save.expect(matcher, _ => value, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockOrders::respond_save(
  self : MockOrders,
  matcher : @mock_runtime.Matcher[PlacedOrder],
  action : (PlacedOrder) -> Unit raise CheckoutError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_save.expect(matcher, action, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockOrders::raise_save(
  self : MockOrders,
  matcher : @mock_runtime.Matcher[PlacedOrder],
  error : CheckoutError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_save.expect(matcher, _ => raise error, times~, sequence?, count?)
}

///|
impl Orders for MockOrders with fn save(self, arg_0) {
  let args = arg_0
  let action = self.slot_save.take(args)
  action(args)
}
