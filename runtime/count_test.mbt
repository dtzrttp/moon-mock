///|
test "范围预期分别检查下限和上限" {
  let controller = @runtime.Controller::new()
  let slot = @runtime.Method::new(controller, "Cache.read")
  slot.expect(
    @runtime.equal_to("item"),
    9,
    count=@runtime.CallCount::between(2, 3),
  )
  assert_true(slot.try_take("item") is Ok(9))
  let missing = controller.missing_calls()
  guard missing is [entry] else { fail("一次调用仍应低于下限") }
  assert_true(entry.contains("Cache.read"))
  assert_true(entry.contains("实际 1 次"))
  assert_true(slot.try_take("item") is Ok(9))
  controller.verify()
  assert_true(slot.try_take("item") is Ok(9))
  guard slot.try_take("item") is Err(error) else {
    fail("第四次调用应超过上限")
  }
  assert_eq(error.code, "too_many_calls")
  assert_true(error.message.contains("3 次上限"))
}

///|
test "可选和无上限次数保留禁止调用语义" {
  @runtime.with_mock(controller => {
    let slot = @runtime.Method::new(controller, "Store.save")
    slot.expect(
      @runtime.equal_to("optional"),
      1,
      count=@runtime.CallCount::between(0, 1),
    )
    slot.expect(
      @runtime.equal_to("never"),
      2,
      count=@runtime.CallCount::exact(0),
    )
    slot.expect(
      @runtime.equal_to("retry"),
      3,
      count=@runtime.CallCount::at_least(2),
    )
    guard slot.try_take("never") is Err(error) else {
      fail("零次上限应拒绝匹配调用")
    }
    assert_eq(error.code, "too_many_calls")
    for _ in 0..<12 {
      assert_true(slot.try_take("retry") is Ok(3))
    }
  })
}

///|
test "有序范围达到下限后可以继续调用，顺序前进后锁定旧步骤" {
  @runtime.with_mock(controller => {
    let prepare : @runtime.Method[Unit, String] = @runtime.Method::new(
      controller, "Job.prepare",
    )
    let commit : @runtime.Method[Unit, String] = @runtime.Method::new(
      controller, "Job.commit",
    )
    let sequence = @runtime.Sequence::new()
    prepare.expect(
      @runtime.any(),
      "ready",
      count=@runtime.CallCount::between(2, 4),
      sequence~,
    )
    commit.expect(@runtime.any(), "done", sequence~)
    assert_true(prepare.try_take(()) is Ok("ready"))
    guard commit.try_take(()) is Err(blocked) else {
      fail("前一步的下限尚未满足")
    }
    assert_eq(blocked.code, "out_of_order")
    assert_true(blocked.message.contains("Job.prepare"))
    assert_true(prepare.try_take(()) is Ok("ready"))
    assert_true(prepare.try_take(()) is Ok("ready"))
    assert_true(commit.try_take(()) is Ok("done"))
    guard prepare.try_take(()) is Err(past) else {
      fail("顺序前进后不能返回旧步骤")
    }
    assert_eq(past.code, "out_of_order")
    assert_true(past.message.contains("Job.commit"))
  })
}

///|
test "有序可选步骤可以跳过，无上限步骤不会阻塞后续" {
  @runtime.with_mock(controller => {
    let step : @runtime.Method[Int32, Int32] = @runtime.Method::new(
      controller, "Task.step",
    )
    let sequence = @runtime.Sequence::new()
    step.expect(
      @runtime.equal_to(0),
      0,
      count=@runtime.CallCount::between(0, 2),
      sequence~,
    )
    step.expect(
      @runtime.equal_to(1),
      10,
      count=@runtime.CallCount::at_least(1),
      sequence~,
    )
    step.expect(@runtime.equal_to(2), 20, sequence~)
    assert_true(step.try_take(1) is Ok(10))
    assert_true(step.try_take(1) is Ok(10))
    assert_true(step.try_take(2) is Ok(20))
  })
}

///|
test "重叠的范围匹配优先使用仍有余量的早期预期" {
  @runtime.with_mock(controller => {
    let slot : @runtime.Method[String, Int32] = @runtime.Method::new(
      controller, "Cache.get",
    )
    slot.expect(@runtime.any(), 1, count=@runtime.CallCount::between(1, 2))
    slot.expect(@runtime.equal_to("a"), 2)
    assert_true(slot.try_take("a") is Ok(1))
    assert_true(slot.try_take("a") is Ok(1))
    assert_true(slot.try_take("a") is Ok(2))
  })
}
