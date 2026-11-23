///|
fn history_controller(capacity : Int32) -> @runtime.Controller raise {
  guard @runtime.Controller::with_history(capacity) is Ok(controller) else {
    fail("有效容量未创建历史控制器：\{capacity}")
  }
  controller
}

///|
test "历史默认关闭且和预期报告独立" {
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Unit, Unit] = @runtime.Method::new(
    controller, "default",
  )
  assert_true(slot.try_take(()) is Err(_))
  slot.expect(@runtime.any(), ())
  slot.take(())
  controller.verify()
  assert_true(controller.history().is_empty())
  assert_eq(controller.history_dropped(), 0L)
  controller.clear_history()
  assert_eq(controller.history_report(), {
    "schema_version": 1,
    "enabled": false,
    "capacity": 0,
    "dropped": "0",
    "events": [],
  })
  assert_eq(controller.report(), {
    "schema_version": 1,
    "closed": false,
    "expectations": Json(controller.snapshot()),
  })
}

///|
test "历史容量拒绝负数、零和资源上限之外的值" {
  for capacity in [-2147483648, -1, 0, 65537, 2147483647] {
    guard @runtime.Controller::with_history(capacity) is Err(error) else {
      fail("接受了无效容量：\{capacity}")
    }
    assert_eq(error.code, "invalid_history_capacity")
    assert_true(error.message.contains(capacity.to_string()))
  }
  let maximum = history_controller(65536)
  assert_true(maximum.history().is_empty())
  guard maximum.history_report() is { "capacity": Number(65536, ..), .. } else {
    fail("应报告实际的容量上限")
  }
}

///|
test "最大历史容量在首次覆盖时保留精确的窗口" {
  let maximum = 65536
  let controller = history_controller(maximum)
  let first : @runtime.Method[Unit, Unit] = @runtime.Method::new(
    controller, "first",
  )
  let repeat : @runtime.Method[Unit, Unit] = @runtime.Method::new(
    controller, "repeat",
  )
  first.expect(@runtime.any(), ())
  repeat.expect(@runtime.any(), (), count=@runtime.CallCount::at_least(0))
  first.take(())
  for _ in 1..<maximum {
    repeat.take(())
  }
  assert_eq(controller.history_dropped(), 0L)
  repeat.take(())
  let events = controller.history()
  assert_eq(events.length(), maximum)
  assert_eq(events[0].ordinal, 2L)
  assert_eq(events[0].method_name, "repeat")
  assert_eq(events[maximum - 1].ordinal, 65537L)
  assert_eq(controller.history_dropped(), 1L)
  controller.verify()
}

///|
test "同名方法的索引依附各自控制器而不受失败登记影响" {
  let left = history_controller(2)
  let right = history_controller(2)
  let first : @runtime.Method[Unit, Unit] = @runtime.Method::new(left, "shared")
  let second : @runtime.Method[Unit, Unit] = @runtime.Method::new(
    left, "shared",
  )
  let independent : @runtime.Method[Unit, Unit] = @runtime.Method::new(
    right, "shared",
  )
  assert_true(
    first.try_expect(@runtime.any(), (), times=-1) is Err(failure) &&
    failure.code == "invalid_count",
  )
  first.expect(@runtime.any(), ())
  independent.expect(@runtime.any(), ())
  second.expect(@runtime.any(), ())
  assert_true(left.history().is_empty())
  assert_true(right.history().is_empty())
  second.take(())
  independent.take(())
  first.take(())
  assert_eq(left.history().map(event => event.ordinal), [1L, 2L])
  assert_eq(left.history().map(event => event.expectation_index), [
    Some(1),
    Some(0),
  ])
  assert_eq(right.history().map(event => event.ordinal), [1L])
  assert_eq(right.history().map(event => event.expectation_index), [Some(0)])
  left.clear_history()
  assert_eq(right.history().length(), 1)
  left.verify()
  right.verify()
}

///|
test "拒绝历史复用调用结果错误码与严格规则优先级" {
  let controller = history_controller(10)
  let sequence = @runtime.Sequence::new()
  let open : @runtime.Method[Unit, Unit] = @runtime.Method::new(
    controller, "open",
  )
  let save : @runtime.Method[String, String] = @runtime.Method::new(
    controller, "save",
  )
  assert_true(
    save.try_take("draft") is Err(error) && error.code == "unexpected_call",
  )
  open.expect(@runtime.any(), (), sequence~)
  save.expect(@runtime.equal_to("draft"), "prohibited", times=0)
  save.expect(@runtime.equal_to("draft"), "saved", sequence~)
  assert_true(
    save.try_take("draft") is Err(error) && error.code == "out_of_order",
  )
  assert_true(
    save.try_take("other") is Err(error) && error.code == "argument_mismatch",
  )
  open.take(())
  assert_true(save.try_take("draft") is Ok("saved"))
  assert_true(
    save.try_take("draft") is Err(error) && error.code == "too_many_calls",
  )
  controller.verify()
  let events = controller.history()
  assert_eq(events.map(event => event.ordinal), [1L, 2L, 3L, 4L, 5L, 6L])
  assert_eq(events.map(event => event.method_name), [
    "save", "save", "save", "open", "save", "save",
  ])
  assert_eq(events.map(event => event.outcome), [
    "rejected", "rejected", "rejected", "selected", "selected", "rejected",
  ])
  assert_eq(events.map(event => event.failure_code), [
    Some("unexpected_call"),
    Some("out_of_order"),
    Some("argument_mismatch"),
    None,
    None,
    Some("too_many_calls"),
  ])
  assert_eq(events.map(event => event.expectation_index), [
    None,
    None,
    None,
    Some(0),
    Some(2),
    None,
  ])
  assert_eq(controller.snapshot().map(status => status.seen), [1, 0, 1])
  assert_eq(controller.history_dropped(), 0L)
}

///|
test "历史只保留最近事件且快照与调用和清理独立" {
  let controller = history_controller(2)
  let slot : @runtime.Method[Unit, Unit] = @runtime.Method::new(
    controller, "bounded",
  )
  slot.expect(@runtime.any(), (), count=@runtime.CallCount::at_least(1))
  slot.take(())
  slot.take(())
  let first = controller.history()
  let report = controller.history_report()
  slot.take(())
  slot.take(())
  slot.take(())
  assert_eq(first.map(event => event.ordinal), [1L, 2L])
  assert_eq(controller.history().map(event => event.ordinal), [4L, 5L])
  assert_eq(controller.history_dropped(), 3L)
  first.clear()
  assert_eq(controller.history().length(), 2)
  controller.clear_history()
  controller.clear_history()
  assert_eq(controller.history_dropped(), 0L)
  assert_true(controller.history().is_empty())
  guard report is { "dropped": String("0"), "events": Array(old), .. } else {
    fail("报告遗漏历史及丢弃统计")
  }
  assert_eq(old.length(), 2)
  assert_eq(controller.snapshot()[0].seen, 5)
  slot.take(())
  assert_eq(controller.history().map(event => event.ordinal), [6L])
  assert_eq(controller.history_dropped(), 0L)
}

///|
test "历史 JSON 保留方法名并排除参数、匹配器说明和错误消息" {
  let controller = history_controller(4)
  let name = "查询\"\n客户🔍"
  let slot : @runtime.Method[String, Unit] = @runtime.Method::new(
    controller, name,
  )
  slot.expect(@runtime.equal_to("expected-secret"), ())
  guard slot.try_take("actual-secret") is Err(error) else {
    fail("错误参数被接受")
  }
  assert_true(error.message.contains("actual-secret"))
  slot.take("expected-secret")
  let report = controller.history_report()
  assert_eq(report, {
    "schema_version": 1,
    "enabled": true,
    "capacity": 4,
    "dropped": "0",
    "events": [
      {
        "ordinal": "1",
        "method_name": name,
        "outcome": "rejected",
        "failure_code": "argument_mismatch",
        "expectation_index": null,
      },
      {
        "ordinal": "2",
        "method_name": name,
        "outcome": "selected",
        "failure_code": null,
        "expectation_index": 0,
      },
    ],
  })
  let encoded = report.stringify()
  assert_true(encoded.contains("\\n"))
  assert_false(encoded.contains("secret"))
}
