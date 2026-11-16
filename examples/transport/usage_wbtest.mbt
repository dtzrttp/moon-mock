///|
suberror ClosingError

///|
async test "传输层首次失败后重试，跨挂起点仍按调用进入顺序记账" {
  @mock_runtime.with_mock_async(async fn(c) {
    let mock = MockTransport::new(c)
    let sequence = @mock_runtime.Sequence::new()
    mock.expect_is_ready(@mock_runtime.any(), true, sequence~)
    mock.raise_fetch(@mock_runtime.equal_to("/health"), Temporary, sequence~)
    mock.respond_fetch(
      @mock_runtime.equal_to("/health"),
      async fn(path) -> String raise TransportError {
        if path.is_empty() {
          raise Temporary
        }
        @async.pause()
        "ok " + path
      },
      sequence~,
    )
    assert_eq(fetch_with_retry(mock, "/health"), "ok /health")
    mock.raise_close(@mock_runtime.any(), ClosingError, sequence~)
    let closed = Ok(Transport::close(mock)) catch { error => Err(error) }
    assert_true(closed is Err(ClosingError))
  })
}

///|
async test "异步响应回调和 noraise 设置均可执行" {
  @mock_runtime.with_mock_async(async fn(c) {
    let mock = MockTransport::new(c)
    mock.respond_is_ready(@mock_runtime.any(), async fn(_) -> Bool noraise {
      @async.pause()
      false
    })
    mock.expect_fetch(@mock_runtime.any(), "forbidden", times=0)
    mock.expect_close(@mock_runtime.any(), ())
    let response = Ok(fetch_with_retry(mock, "/health")) catch {
      error => Err(error)
    }
    assert_true(response is Err(Temporary))
    Transport::close(mock)
    mock.respond_close(@mock_runtime.any(), async fn(_) { @async.pause() })
    Transport::close(mock)
  })
}
