///|
fn[T : Service] read_from_service(
  service : T,
  id : Int32,
) -> String raise ServiceError {
  let label = Named::name(service)
  let item = Reader::lookup(service, id~)
  Endpoint::close(service)
  label + "/" + item
}

///|
test "从三个源码文件生成的继承 mock 可传入泛型调用方" {
  @mock_runtime.with_mock(c => {
    let service = MockService::new(c)
    let sequence = @mock_runtime.Sequence::new()
    service.expect_name(@mock_runtime.any(), "catalog", sequence~)
    service.expect_lookup(@mock_runtime.equal_to(12), "book", sequence~)
    service.expect_close(@mock_runtime.any(), (), sequence~)
    assert_eq(read_from_service(service, 12), "catalog/book")
  })
}

///|
test "菱形继承的祖先预期由全部分支共享" {
  @mock_runtime.with_mock(c => {
    let mock = MockService::new(c)
    mock.expect_name(
      @mock_runtime.any(),
      "shared",
      count=@mock_runtime.CallCount::between(1, 3),
    )
    mock.expect_ready(@mock_runtime.any(), false)
    let health : &Health = mock
    assert_eq(Named::name(mock), "shared")
    assert_false(health.ready())
    assert_eq(Named::name(mock), "shared")
  })
}

///|
test "继承方法保留标签参数和类型化错误" {
  @mock_runtime.with_mock(c => {
    let mock = MockService::new(c)
    let reader : &Reader = mock
    mock.expect_lookup(@mock_runtime.equal_to(7), "ok")
    mock.raise_lookup(@mock_runtime.equal_to(8), OfflineService)
    assert_eq(reader.lookup(id=7), "ok")
    let failed = Ok(reader.lookup(id=8)) catch { error => Err(error) }
    assert_true(failed is Err(OfflineService))
  })
}
