// 由 moon-mock 生成，请从原 trait 重新生成。

///|
struct MockInventory {
  slot_reserve : @mock_runtime.Method[
    (String, Int32),
    ((String, Int32)) -> String raise CheckoutError,
  ]
  slot_release : @mock_runtime.Method[
    String,
    (String) -> Unit raise CheckoutError,
  ]
}

///|
#warnings("-unused_value")
fn MockInventory::new(c : @mock_runtime.Controller) -> MockInventory {
  {
    slot_reserve: @mock_runtime.Method::new(c, "Inventory.reserve"),
    slot_release: @mock_runtime.Method::new(c, "Inventory.release"),
  }
}

///|
#warnings("-unused_value")
fn MockInventory::expect_reserve(
  self : MockInventory,
  matcher : @mock_runtime.Matcher[(String, Int32)],
  value : String,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_reserve.expect(matcher, _ => value, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockInventory::respond_reserve(
  self : MockInventory,
  matcher : @mock_runtime.Matcher[(String, Int32)],
  action : ((String, Int32)) -> String raise CheckoutError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_reserve.expect(matcher, action, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockInventory::raise_reserve(
  self : MockInventory,
  matcher : @mock_runtime.Matcher[(String, Int32)],
  error : CheckoutError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_reserve.expect(matcher, _ => raise error, times~, sequence?, count?)
}

///|
impl Inventory for MockInventory with fn reserve(self, arg_0, arg_1) {
  let args = (arg_0, arg_1)
  let action = self.slot_reserve.take(args)
  action(args)
}

///|
#warnings("-unused_value")
fn MockInventory::expect_release(
  self : MockInventory,
  matcher : @mock_runtime.Matcher[String],
  value : Unit,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_release.expect(matcher, _ => value, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockInventory::respond_release(
  self : MockInventory,
  matcher : @mock_runtime.Matcher[String],
  action : (String) -> Unit raise CheckoutError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_release.expect(matcher, action, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockInventory::raise_release(
  self : MockInventory,
  matcher : @mock_runtime.Matcher[String],
  error : CheckoutError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_release.expect(matcher, _ => raise error, times~, sequence?, count?)
}

///|
impl Inventory for MockInventory with fn release(self, arg_0) {
  let args = arg_0
  let action = self.slot_release.take(args)
  action(args)
}
