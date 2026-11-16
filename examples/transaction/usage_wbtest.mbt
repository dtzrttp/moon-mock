///|
test "事务成功时提交，写入失败时回滚" {
  @mock_runtime.with_mock(c => {
    let mock = MockTransaction::new(c)
    let sequence = @mock_runtime.Sequence::new()
    mock.expect_begin(@mock_runtime.any(), (), sequence~)
    mock.expect_insert(@mock_runtime.equal_to(("alice", 120)), (), sequence~)
    mock.expect_commit(@mock_runtime.any(), (), sequence~)
    mock.expect_rollback(@mock_runtime.any(), (), times=0)
    transfer(mock, "alice", 120)
  })
  @mock_runtime.with_mock(c => {
    let mock = MockTransaction::new(c)
    let sequence = @mock_runtime.Sequence::new()
    mock.expect_begin(@mock_runtime.any(), (), sequence~)
    mock.raise_insert(
      @mock_runtime.equal_to(("bob", 30)),
      WriteFailed,
      sequence~,
    )
    mock.expect_rollback(@mock_runtime.any(), (), sequence~)
    mock.expect_commit(@mock_runtime.any(), (), times=0)
    let outcome = Ok(transfer(mock, "bob", 30)) catch { error => Err(error) }
    assert_true(outcome is Err(WriteFailed))
  })
}

///|
test "生成的同步回调可根据参数计算行为" {
  @mock_runtime.with_mock(c => {
    let mock = MockTransaction::new(c)
    let observed = []
    mock.respond_begin(@mock_runtime.any(), _ => ())
    mock.respond_insert(@mock_runtime.any(), args => observed.push(args))
    mock.respond_commit(@mock_runtime.any(), _ => ())
    mock.respond_rollback(@mock_runtime.any(), _ => (), times=0)
    transfer(mock, "bob", 30)
    assert_eq(observed, [("bob", 30)])
  })
}
