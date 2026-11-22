///|
test "登记失败保持预期列表和序列原样" {
  let first = @runtime.Controller::new()
  let second = @runtime.Controller::new()
  let sequence = @runtime.Sequence::new()
  let a : @runtime.Method[Unit, Int32] = @runtime.Method::new(first, "a")
  let b : @runtime.Method[Unit, Int32] = @runtime.Method::new(second, "b")
  a.expect(@runtime.any(), 1, sequence~)
  guard b.try_expect(@runtime.any(), 2, sequence~) is Err(failure) else {
    fail("不能跨测试共享有状态的顺序组")
  }
  assert_eq(failure.code, "sequence_controller_mismatch")
  assert_eq(second.snapshot().length(), 0)
  assert_true(b.try_expect(@runtime.any(), 2, times=-1) is Err(_))
  assert_true(
    b.try_expect(@runtime.any(), 2, times=2, count=@runtime.CallCount::exact(3))
    is Err(_),
  )
  assert_eq(second.snapshot().length(), 0)
  assert_true(b.try_expect(@runtime.any(), 2) is Ok(_))
  assert_eq(b.take(()), 2)
  assert_eq(a.take(()), 1)
  first.verify()
  second.verify()
}

///|
test "次数和调用统计快照按登记顺序输出且不会追踪后续调用" {
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[String, Int32] = @runtime.Method::new(
    controller, "查询\"\n中文",
  )
  slot.expect(
    @runtime.equal_to("a"),
    1,
    count=@runtime.CallCount::between(1, 2),
  )
  slot.expect(@runtime.equal_to("b"), 2, times=0)
  let before = controller.snapshot()
  assert_eq(before[0].seen, 0)
  assert_false(before[0].satisfied)
  assert_eq(before[1].maximum, Some(0))
  slot.take("a") |> ignore
  let after = controller.snapshot()
  assert_eq(before[0].seen, 0)
  assert_eq(after[0].seen, 1)
  assert_true(after[0].satisfied)
  let json = controller.report().stringify()
  assert_true(json.contains("schema_version"))
  assert_true(json.contains("expectations"))
  assert_true(json.contains("\\n"))
}

///|
test "作用域结束后可查询报告，新增预期返回 scope_closed" {
  let controller = @runtime.with_mock(controller => controller)
  let slot : @runtime.Method[Int32, Int32] = @runtime.Method::new(
    controller, "closed",
  )
  guard slot.try_expect(@runtime.any(), 1) is Err(failure) else {
    fail("作用域应关闭")
  }
  assert_eq(failure.code, "scope_closed")
  assert_eq(controller.snapshot().length(), 0)
  assert_true(controller.report().stringify().contains("true"))
}

///|
test "非法次数范围可以在登记前处理" {
  assert_true(@runtime.CallCount::try_between(-1, 1) is Err(_))
  assert_true(@runtime.CallCount::try_between(2, 1) is Err(_))
  assert_true(@runtime.CallCount::try_at_least(-1) is Err(_))
  assert_true(@runtime.CallCount::try_between(0, 0) is Ok(_))
  assert_true(@runtime.CallCount::try_at_least(2147483647) is Ok(_))
}
