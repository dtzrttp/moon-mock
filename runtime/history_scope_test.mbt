///|
suberror HistoryBodyFailed

///|
test "默认作用域函数仍可作为原签名的回调传递" {
  let scope : ((@runtime.Controller) -> Int32 raise) -> Int32 raise = @runtime.with_mock
  assert_eq(
    scope(controller => {
      assert_true(controller.history().is_empty())
      17
    }),
    17,
  )
}

///|
async test "默认异步作用域也保留原函数类型" {
  let scope : async (async (@runtime.Controller) -> Int32) -> Int32 = @runtime.with_mock_async
  assert_eq(
    scope(controller => {
      @async.pause()
      assert_true(controller.history().is_empty())
      17
    }),
    17,
  )
}

///|
test "作用域拒绝无效历史配置且从未执行测试体" {
  let ran = Ref(false)
  let result = Ok(@runtime.with_mock_history(0, _ => ran.val = true)) catch {
    error => Err(error)
  }
  assert_true(result is Err(@runtime.InvalidHistoryCapacity(_)))
  assert_false(ran.val)
}

///|
test "启用历史的同步作用域完成核对后继续记录关闭错误" {
  let (controller, slot) = @runtime.with_mock_history(2, controller => {
    let slot : @runtime.Method[Int32, Int32] = @runtime.Method::new(
      controller, "done",
    )
    slot.expect(@runtime.any(), 41)
    assert_eq(slot.take(12), 41)
    (controller, slot)
  })
  assert_true(
    slot.try_expect(@runtime.any(), 17) is Err(failure) &&
    failure.code == "scope_closed",
  )
  assert_eq(controller.history().length(), 1)
  assert_true(
    slot.try_take(5) is Err(failure) && failure.code == "scope_closed",
  )
  let events = controller.history()
  assert_eq(events.map(event => event.ordinal), [1L, 2L])
  assert_eq(events.map(event => event.failure_code), [
    None,
    Some("scope_closed"),
  ])
  assert_eq(controller.snapshot()[0].seen, 1)
}

///|
test "同步测试体出错时传播原错误并保留关闭前后的历史" {
  let escaped : Ref[(@runtime.Controller, @runtime.Method[Unit, Unit])?] = Ref(
    None,
  )
  let result : Result[Unit, Error] = Ok(
    @runtime.with_mock_history(3, controller => {
      let slot : @runtime.Method[Unit, Unit] = @runtime.Method::new(
        controller, "body",
      )
      slot.expect(@runtime.any(), (), times=2)
      slot.take(())
      escaped.val = Some((controller, slot))
      raise HistoryBodyFailed
    }),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(HistoryBodyFailed))
  guard escaped.val is Some((controller, slot)) else {
    fail("测试体没有发布检查对象")
  }
  assert_true(
    slot.try_take(()) is Err(failure) && failure.code == "scope_closed",
  )
  let events = controller.history()
  assert_eq(events.map(event => event.outcome), ["selected", "rejected"])
  assert_eq(events.map(event => event.failure_code), [
    None,
    Some("scope_closed"),
  ])
  assert_eq(controller.snapshot()[0].seen, 1)
}

///|
test "自动核对失败后历史仍可读取且不会记录核对本身" {
  let escaped : Ref[(@runtime.Controller, @runtime.Method[Unit, Unit])?] = Ref(
    None,
  )
  let result = Ok(
    @runtime.with_mock_history(2, controller => {
      let slot : @runtime.Method[Unit, Unit] = @runtime.Method::new(
        controller, "verify",
      )
      slot.expect(@runtime.any(), (), times=2)
      slot.take(())
      escaped.val = Some((controller, slot))
    }),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(@runtime.VerificationFailed(_)))
  guard escaped.val is Some((controller, slot)) else {
    fail("测试体没有发布检查对象")
  }
  assert_eq(controller.history().map(event => event.outcome), ["selected"])
  assert_true(
    slot.try_take(()) is Err(failure) && failure.code == "scope_closed",
  )
  assert_eq(controller.history().map(event => event.failure_code), [
    None,
    Some("scope_closed"),
  ])
}

///|
test "成功选中在监听器和业务回调执行前进入历史" {
  let controller = history_controller(3)
  let slot : @runtime.Method[Unit, () -> Unit raise] = @runtime.Method::new(
    controller, "start",
  )
  let adjacent : @runtime.Method[Unit, Unit] = @runtime.Method::new(
    controller, "notify",
  )
  slot.expect(
    @runtime.Matcher::custom("启动观察", _ => true, on_selected=_ => {
      adjacent.take(())
    }),
    () => raise HistoryBodyFailed,
  )
  adjacent.expect(@runtime.any(), ())
  let action = slot.take(())
  let result = Ok(action()) catch { error => Err(error) }
  assert_true(result is Err(HistoryBodyFailed))
  let events = controller.history()
  assert_eq(events.map(event => event.method_name), ["start", "notify"])
  assert_eq(events.map(event => event.outcome), ["selected", "selected"])
  assert_eq(events.map(event => event.expectation_index), [Some(0), Some(1)])
  controller.verify()
}

///|
async test "异步作用域在运行测试体之前验证容量" {
  let ran = Ref(false)
  let result = Ok(
    @runtime.with_mock_history_async(65537, _ => {
      @async.pause()
      ran.val = true
    }),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(@runtime.InvalidHistoryCapacity(_)))
  assert_false(ran.val)
}

///|
async test "协作任务先同步选中再异步返回并按选中顺序保留尾部" {
  @runtime.with_mock_history_async(5, controller => {
    let slot : @runtime.Method[Int32, async () -> Int32] = @runtime.Method::new(
      controller, "concurrent",
    )
    let selected = []
    for value in 0..<24 {
      let matcher = @runtime.Matcher::custom(
        "任务 \{value}",
        actual => actual == value,
        on_selected=actual => selected.push(actual),
      )
      slot.expect(matcher, async fn() {
        @async.pause()
        value * 2
      })
    }
    @async.with_task_group(group => {
      let tasks = []
      for value in 0..<24 {
        tasks.push(group.spawn(() => slot.take(value)()))
      }
      for i, task in tasks {
        assert_eq(task.wait(), i * 2)
      }
    })
    let events = controller.history()
    assert_eq(events.map(event => event.ordinal), [20L, 21L, 22L, 23L, 24L])
    assert_eq(controller.history_dropped(), 19L)
    assert_eq(selected.length(), 24)
    for i, event in events {
      assert_eq(event.expectation_index, Some(selected[i + 19]))
      assert_eq(event.outcome, "selected")
      assert_true(event.failure_code is None)
    }
  })
}

///|
async test "取消未完成的异步回调后记录关闭错误且保留选中" {
  let ready : @aqueue.Queue[
    (@runtime.Controller, @runtime.Method[Unit, async () -> Unit]),
  ] = @aqueue.Queue(kind=Unbounded)
  let hold : @aqueue.Queue[Unit] = @aqueue.Queue(kind=Unbounded)
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        @runtime.with_mock_history_async(2, controller => {
          let slot : @runtime.Method[Unit, async () -> Unit] = @runtime.Method::new(
            controller, "pending",
          )
          slot.expect(
            @runtime.any(),
            async fn() {
              ready.put((controller, slot))
              hold.get()
            },
            times=2,
          )
          slot.take(())()
        })
      })
    })
    let (controller, slot) = ready.get()
    assert_eq(controller.history().map(event => event.ordinal), [1L])
    task.cancel()
    ignore(task.wait())
    assert_true(
      slot.try_take(()) is Err(failure) && failure.code == "scope_closed",
    )
    assert_eq(controller.snapshot()[0].seen, 1)
    let events = controller.history()
    assert_eq(events.map(event => event.ordinal), [1L, 2L])
    assert_eq(events.map(event => event.outcome), ["selected", "rejected"])
    assert_eq(events.map(event => event.failure_code), [
      None,
      Some("scope_closed"),
    ])
  })
}
