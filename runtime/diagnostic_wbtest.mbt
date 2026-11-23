///|
test "成功选择后续预期不会构造实际值诊断" {
  let render_count = Ref(0)
  let reject : Matcher[Int32] = Matcher::custom("拒绝", _ => false, describe_actual=value => {
    render_count.val += 1
    value.to_string()
  })
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

///|
test "延迟诊断保持登记顺序且不会再次执行谓词" {
  let checked = Ref(0)
  let rendered = Ref(0)
  let controller = Controller::new()
  let slot : Method[Int32, Unit] = Method::new(controller, "lookup")
  slot.expect(
    matching("第一个", _ => {
      checked.val += 1
      false
    }),
    (),
  )
  let detailed : Matcher[Int32] = Matcher::custom(
    "第二个",
    _ => {
      checked.val += 1
      false
    },
    describe_actual=value => {
      rendered.val += 1
      value.to_string()
    },
  )
  slot.expect(detailed, ())
  guard slot.try_take(99) is Err(error) else { fail("应报告参数不符") }
  assert_eq(error.code, "argument_mismatch")
  assert_eq(
    error.message,
    "lookup 的参数未匹配预期：第一个、第二个，实际参数 99",
  )
  assert_eq(checked.val, 2)
  assert_eq(rendered.val, 1)
  assert_eq(controller.snapshot()[0].seen, 0)
  assert_eq(controller.snapshot()[1].seen, 0)
}

///|
test "次数和顺序失败优先且不渲染参数" {
  let rendered = Ref(0)
  let reject : Matcher[Int32] = Matcher::custom("拒绝", _ => false, describe_actual=value => {
    rendered.val += 1
    value.to_string()
  })
  let controller = Controller::new()
  let sequence = Sequence::new()
  let prior : Method[Unit, Unit] = Method::new(controller, "prior")
  prior.expect(any(), (), sequence~)
  let slot : Method[Int32, Unit] = Method::new(controller, "next")
  slot.expect(reject, ())
  slot.expect(any(), (), times=0)
  slot.expect(any(), (), sequence~)
  guard slot.try_take(99) is Err(blocked) else { fail("应报告顺序阻塞") }
  assert_eq(blocked.code, "out_of_order")
  assert_eq(rendered.val, 0)
  assert_true(prior.try_take(()) is Ok(_))
  assert_true(slot.try_take(99) is Ok(_))
  guard slot.try_take(99) is Err(exhausted) else {
    fail("应报告次数上限")
  }
  assert_eq(exhausted.code, "too_many_calls")
  assert_eq(rendered.val, 0)
}
