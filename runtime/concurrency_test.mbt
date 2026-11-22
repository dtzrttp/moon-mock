///|
async test "32个协作任务共享方法时在挂起前完成记账和捕获" {
  let captured : @runtime.Capture[Int32] = @runtime.Capture::new()
  @runtime.with_mock_async(async fn(controller) {
    let slot : @runtime.Method[Int32, async (Int32) -> Int32] = @runtime.Method::new(
      controller, "concurrent",
    )
    slot.expect(
      captured.matcher(@runtime.any()),
      async fn(value) {
        @async.pause()
        value * 2
      },
      times=32,
    )
    @async.with_task_group(group => {
      let tasks = []
      for i in 0..<32 {
        let value = i
        tasks.push(
          group.spawn(() => {
            let action = slot.take(value)
            action(value)
          }),
        )
      }
      for i, task in tasks {
        assert_eq(task.wait(), i * 2)
      }
    })
    assert_eq(controller.snapshot()[0].seen, 32)
    let values = captured.values()
    assert_eq(values.length(), 32)
    for i in 0..<32 {
      assert_true(values.contains(i))
    }
  })
}

///|
async test "挂起后的业务错误不会撤销已选中的预期" {
  @runtime.with_mock_async(async fn(controller) {
    let slot : @runtime.Method[Unit, async () -> Unit] = @runtime.Method::new(
      controller, "failure",
    )
    slot.expect(@runtime.any(), async fn() {
      @async.pause()
      raise AsyncFailure
    })
    let failure = Ok(slot.take(())()) catch { error => Err(error) }
    assert_true(failure is Err(AsyncFailure))
    assert_true(controller.snapshot()[0].satisfied)
  })
}

///|
suberror AsyncFailure
