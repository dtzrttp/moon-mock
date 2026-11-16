///|
test "匹配参数、选择预期并记账" {
  let c = @runtime.Controller::new()
  let slot = @runtime.Method::new(c, "Cache.get")
  slot.expect(@runtime.equal_to("a"), "A", times=2)
  slot.expect(@runtime.matching("以 b 开头", x => x.has_prefix("b")), "B")
  assert_eq(slot.take("a"), "A")
  assert_eq(slot.take("beta"), "B")
  assert_eq(c.missing_calls().length(), 1)
  assert_eq(slot.take("a"), "A")
  c.verify()
}

///|
test "区分方法未配置、参数不符和调用过多" {
  let c = @runtime.Controller::new()
  let slot : @runtime.Method[Int32, String] = @runtime.Method::new(
    c, "Repo.find",
  )
  guard slot.try_take(1) is Err(unexpected) else { fail("应当失败") }
  assert_eq(unexpected.code, "unexpected_call")
  slot.expect(@runtime.equal_to(1), "one")
  guard slot.try_take(2) is Err(mismatch) else { fail("应当失败") }
  assert_eq(mismatch.code, "argument_mismatch")
  assert_true(mismatch.message.contains("Repo.find"))
  assert_true(mismatch.message.contains("实际参数 2"))
  assert_eq(slot.take(1), "one")
  guard slot.try_take(1) is Err(excess) else { fail("应当失败") }
  assert_eq(excess.code, "too_many_calls")
}

///|
test "显式顺序可横跨方法并支持重复次数" {
  let c = @runtime.Controller::new()
  let sequence = @runtime.Sequence::new()
  let load = @runtime.Method::new(c, "load")
  let save = @runtime.Method::new(c, "save")
  load.expect(@runtime.any(), 7, times=2, sequence~)
  save.expect(@runtime.any(), (), sequence~)
  guard save.try_take(()) is Err(error) else { fail("应报告顺序") }
  assert_eq(error.code, "out_of_order")
  assert_true(error.message.contains("load"))
  assert_eq(load.take("x"), 7)
  assert_true(save.try_take(()) is Err(_))
  assert_eq(load.take("y"), 7)
  save.take(())
  c.verify()
}

///|
test "自动核对成功分支，并保留测试体原错误" {
  let result = Ok(
    @runtime.with_mock(c => {
      let next = @runtime.Method::new(c, "next")
      next.expect(@runtime.any(), 17)
      next.take(())
    }),
  ) catch {
    e => Err(e)
  }
  assert_true(result is Ok(17))
  let missing = Ok(
    @runtime.with_mock(c => {
      let next : @runtime.Method[Unit, Int32] = @runtime.Method::new(c, "next")
      next.expect(@runtime.any(), 17)
    }),
  ) catch {
    e => Err(e)
  }
  assert_true(missing is Err(@runtime.VerificationFailed(_)))
  let original : Result[Unit, Error] = Ok(
    @runtime.with_mock(c => {
      let next : @runtime.Method[Unit, Int32] = @runtime.Method::new(c, "next")
      next.expect(@runtime.any(), 17)
      raise OriginalError
    }),
  ) catch {
    e => Err(e)
  }
  assert_true(original is Err(OriginalError))
}

///|
suberror OriginalError

///|
async test "异步作用域也自动核对剩余预期" {
  let outcome = Ok(
    @runtime.with_mock_async(async fn(c) {
      @async.pause()
      let slot = @runtime.Method::new(c, "async")
      slot.expect(@runtime.any(), 42, times=2)
      ignore(slot.take(()))
    }),
  ) catch {
    e => Err(e)
  }
  assert_true(outcome is Err(@runtime.VerificationFailed(_)))
}

///|
test "禁用预期拒绝首次调用，测试结束后禁止继续调用" {
  let slot = @runtime.with_mock(c => {
    let slot : @runtime.Method[Unit, Int32] = @runtime.Method::new(c, "publish")
    slot.expect(@runtime.any(), 1, times=0)
    guard slot.try_take(()) is Err(unexpected) else {
      fail("禁用预期错误地接受了调用")
    }
    assert_eq(unexpected.code, "too_many_calls")
    slot
  })
  guard slot.try_take(()) is Err(closed) else {
    fail("已结束的作用域仍接受调用")
  }
  assert_eq(closed.code, "scope_closed")
}

///|
async test "取消异步测试体后关闭作用域，剩余预期不会替换取消" {
  let ready : @aqueue.Queue[@runtime.Method[Unit, Int32]] = @aqueue.Queue(
    kind=Unbounded,
  )
  let never : @aqueue.Queue[Unit] = @aqueue.Queue(kind=Unbounded)
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        @runtime.with_mock_async(body => {
          let slot : @runtime.Method[Unit, Int32] = @runtime.Method::new(
            body, "pending",
          )
          slot.expect(@runtime.any(), 1)
          ready.put(slot)
          never.get()
        })
      })
    })
    let slot = ready.get()
    task.cancel()
    // 等待取消完成后再访问逃逸的 mock。
    ignore(task.wait())
    guard slot.try_take(()) is Err(closed) else {
      fail("取消后作用域仍开放")
    }
    assert_eq(closed.code, "scope_closed")
  })
}
