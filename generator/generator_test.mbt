///|
test "只生成指定 trait，保持类型和错误效果" {
  let source =
    #|trait Skip { fn skip(Self) -> Unit }
    #|trait Repository {
    #|  fn get(Self, String, Int) -> String?
    #|  fn delete(Self, String) -> Unit raise
    #|  async fn save(Self, String) -> Unit raise WriteError
    #|  async fn count(Self) -> Int noraise
    #|}
  let out = @generator.generate(source, "Repository")
  assert_true(out.contains("impl Repository for MockRepository"))
  assert_true(out.contains("expect_get"))
  assert_true(out.contains("raise_save"))
  assert_true(out.contains("raise_delete"))
  assert_true(out.contains("raise WriteError"))
  assert_true(out.contains("noraise"))
  assert_false(out.contains("MockSkip"))
  assert_false(out.contains("raise_count"))
  assert_eq(@generator.generate(source, "Repository"), out)
}

///|
test "允许为已有同名测试替身的包指定生成类型名" {
  let source = "trait Transport { async fn send(Self, Int32) -> Int32 }"
  let output = @generator.generate(
    source,
    "Transport",
    mock_name="GeneratedTransport",
  )
  assert_true(output.contains("impl Transport for GeneratedTransport"))
  assert_false(output.contains("MockTransport"))
  let rejected = Ok(
    @generator.generate(source, "Transport", mock_name="Bad Name"),
  ) catch {
    @generator.GenerationError(message) => Err(message)
  }
  assert_true(rejected is Err(message) && message.contains("invalid_mock_name"))
}

///|
test "解析错误和不存在的 trait 给出清楚的错误" {
  for
    (source, name, expected) in [
      ("trait Foo {", "Foo", "parse_error"),
      ("trait Foo {}", "Other", "trait_not_found"),
    ] {
    let output = Ok(@generator.generate(source, name, filename="traits.mbt")) catch {
      @generator.GenerationError(message) => Err(message)
    }
    guard output is Err(message) else { fail("应拒绝输入") }
    assert_true(message.contains(expected))
    assert_true(message.contains("traits.mbt"))
  }
}

///|
test "生成默认方法的显式覆盖" {
  let source =
    #|trait Source {
    #|  fn read(Self) -> Int raise ReadError = _
    #|  async fn ready(Self) -> Bool noraise = _
    #|}
  let out = @generator.generate(source, "Source")
  assert_true(out.contains("impl Source for MockSource with fn read"))
  assert_true(out.contains("expect_read"))
  assert_true(out.contains("raise_read"))
  assert_true(out.contains("expect_ready"))
}

///|
test "保留参数和返回值中的 trait 对象类型" {
  let source = "trait Source { fn convert(Self, &@io.Input) -> &Output }"
  let out = @generator.generate(source, "Source")
  assert_true(out.contains("&@io.Input"))
  assert_true(out.contains("-> &Output"))
}

///|
test "拒绝未支持的签名并标记源码位置" {
  for
    source in [
      "trait Foo : Base { fn f(Self) -> Unit }", "trait Foo { fn[A] f(Self, A) -> A }",
      "trait Foo { fn f(Self, id~ : Int) -> Int }", "trait Foo { fn f(Self) -> Self }",
    ] {
    let result = Ok(@generator.generate(source, "Foo", filename="traits.mbt")) catch {
      @generator.GenerationError(message) => Err(message)
    }
    guard result is Err(message) else { fail("应拒绝输入：" + source) }
    assert_true(message.contains("traits.mbt:1:"))
    assert_true(message.contains("unsupported_signature"))
  }
}
