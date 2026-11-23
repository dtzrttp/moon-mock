///|
test "历史序号和丢弃数饱和时循环缓冲区仍保留最近事件" {
  guard Controller::with_history(1) is Ok(controller) else {
    fail("容量 1 应受支持")
  }
  guard controller.history_buffer is Some(history) else {
    fail("未启用历史缓冲区")
  }
  let slot : Method[Unit, Unit] = Method::new(controller, "overflow")
  slot.expect(any(), (), count=CallCount::at_least(0))
  history.last_ordinal = 9223372036854775805L
  history.dropped = 9223372036854775806L
  slot.take(())
  assert_eq(controller.history()[0].ordinal, 9223372036854775806L)
  assert_eq(controller.history_dropped(), 9223372036854775806L)
  slot.take(())
  assert_eq(controller.history()[0].ordinal, 9223372036854775807L)
  assert_eq(controller.history_dropped(), 9223372036854775807L)
  slot.take(())
  assert_eq(controller.history()[0].ordinal, 9223372036854775807L)
  assert_eq(controller.history_dropped(), 9223372036854775807L)
  let report = controller.history_report()
  guard report
    is {
      "dropped": String("9223372036854775807"),
      "events": [{ "ordinal": String("9223372036854775807"), .. }],
      ..
    } else {
    fail("JSON 报告应精确保存超过浮点数整数精度的计数")
  }
  controller.clear_history()
  assert_eq(controller.history_dropped(), 0L)
  slot.take(())
  assert_eq(controller.history()[0].ordinal, 9223372036854775807L)
  assert_eq(controller.snapshot()[0].seen, 4)
}
