///|
test "成功选择后续预期不会构造实际值诊断" {
  let render_count = Ref(0)
  let reject : Matcher[Int32] = {
    description: "拒绝",
    accepts: _ => false,
    describe_actual: Some(value => {
      render_count.val += 1
      value.to_string()
    }),
    on_selected: None,
  }
  let controller = Controller::new()
  let slot : Method[Int32, Int32] = Method::new(controller, "late")
  slot.expect(reject, 0, times=0)
  slot.expect(equal_to(42), 42)
  assert_true(slot.try_take(42) is Ok(42))
  assert_eq(render_count.val, 0)
  guard slot.try_take(99) is Err(error) else { fail("应该失败") }
  assert_true(error.message.contains("实际参数 99"))
  assert_eq(render_count.val, 1)
}

///|
test "无上限计数在整数上界饱和" {
  let controller = Controller::new()
  let slot : Method[Unit, Unit] = Method::new(controller, "many")
  slot.expect(any(), (), count=CallCount::at_least(1))
  controller.tickets[0].seen = 2147483647
  assert_true(slot.try_take(()) is Ok(_))
  assert_eq(controller.snapshot()[0].seen, 2147483647)
  controller.verify()
}
