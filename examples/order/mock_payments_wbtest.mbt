// 由 moon-mock 生成，请从原 trait 重新生成。

///|
struct MockPayments {
  slot_charge : @mock_runtime.Method[
    (String, Int32),
    ((String, Int32)) -> String raise CheckoutError,
  ]
  slot_refund : @mock_runtime.Method[
    String,
    (String) -> Unit raise CheckoutError,
  ]
}

///|
#warnings("-unused_value")
fn MockPayments::new(c : @mock_runtime.Controller) -> MockPayments {
  {
    slot_charge: @mock_runtime.Method::new(c, "Payments.charge"),
    slot_refund: @mock_runtime.Method::new(c, "Payments.refund"),
  }
}

///|
#warnings("-unused_value")
fn MockPayments::expect_charge(
  self : MockPayments,
  matcher : @mock_runtime.Matcher[(String, Int32)],
  value : String,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_charge.expect(matcher, _ => value, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockPayments::respond_charge(
  self : MockPayments,
  matcher : @mock_runtime.Matcher[(String, Int32)],
  action : ((String, Int32)) -> String raise CheckoutError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_charge.expect(matcher, action, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockPayments::raise_charge(
  self : MockPayments,
  matcher : @mock_runtime.Matcher[(String, Int32)],
  error : CheckoutError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_charge.expect(matcher, _ => raise error, times~, sequence?, count?)
}

///|
impl Payments for MockPayments with fn charge(self, arg_0, arg_1) {
  let args = (arg_0, arg_1)
  let action = self.slot_charge.take(args)
  action(args)
}

///|
#warnings("-unused_value")
fn MockPayments::expect_refund(
  self : MockPayments,
  matcher : @mock_runtime.Matcher[String],
  value : Unit,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_refund.expect(matcher, _ => value, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockPayments::respond_refund(
  self : MockPayments,
  matcher : @mock_runtime.Matcher[String],
  action : (String) -> Unit raise CheckoutError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_refund.expect(matcher, action, times~, sequence?, count?)
}

///|
#warnings("-unused_value")
fn MockPayments::raise_refund(
  self : MockPayments,
  matcher : @mock_runtime.Matcher[String],
  error : CheckoutError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
  count? : @mock_runtime.CallCount,
) -> Unit {
  self.slot_refund.expect(matcher, _ => raise error, times~, sequence?, count?)
}

///|
impl Payments for MockPayments with fn refund(self, arg_0) {
  let args = arg_0
  let action = self.slot_refund.take(args)
  action(args)
}
