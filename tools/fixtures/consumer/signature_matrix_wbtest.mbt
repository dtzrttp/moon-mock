///|
test "96种签名组合生成后可由真实编译器检查" {
  @mock_runtime.with_mock(c => {
    let mock = MockSignatureMatrix::new(c)
    mock.expect_method_0(@mock_runtime.any(), ())
    SignatureMatrix::method_0(mock, 1)
  })
}
