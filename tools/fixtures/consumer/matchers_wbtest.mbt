///|
test "生成的继承 mock 组合匹配、捕获业务参数并导出报告" {
  let ids : @mock_runtime.Capture[Int32] = @mock_runtime.Capture::new()
  @mock_runtime.with_mock(controller => {
    let service = MockService::new(controller)
    let accepted = @mock_runtime.matching("正数", (id : Int32) => id > 0)
      .and_(@mock_runtime.one_of([7, 42]))
    service.expect_lookup(
      ids.matcher(accepted),
      "book",
      count=@mock_runtime.CallCount::between(1, 2),
    )
    assert_eq(Reader::lookup(service, id=42), "book")
    assert_eq(Reader::lookup(service, id=7), "book")
    assert_eq(ids.values(), [42, 7])
    let statuses = controller.snapshot()
    assert_eq(statuses[0].method_name, "Reader.lookup")
    assert_eq(statuses[0].seen, 2)
    assert_true(statuses[0].satisfied)
    assert_true(controller.report().stringify().contains("schema_version"))
  })
}
