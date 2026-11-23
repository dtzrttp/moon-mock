///|
test "结构化解析诊断保留完整 Windows 文件名与位置" {
  let file = "D:\\项目:示例\\traits.mbt"
  let source = "trait Valid {}\ntrait Bad { fn broken(Self) -> }"
  let result = @generator.try_generate(source, "Valid", filename=file)
  guard result is Err([first, ..]) else {
    fail("应提供至少一个解析诊断")
  }
  assert_eq(first.filename, file)
  assert_eq(first.code, "parse_error")
  assert_eq(first.line, Some(2))
  guard first.column is Some(column) else { fail("解析错误缺少列号") }
  assert_true(column > 1)
  assert_false(first.message.is_empty())
}

///|
test "无法定位到声明时结构化诊断省去行和列" {
  let result = @generator.try_generate(
    "trait Api {}",
    "Missing",
    filename="D:\\api.mbt",
  )
  guard result is Err([error]) else {
    fail("应返回未找到声明的诊断")
  }
  assert_eq(error.code, "trait_not_found")
  assert_eq(error.filename, "D:\\api.mbt")
  assert_eq(error.line, None)
  assert_eq(error.column, None)
  assert_eq(error.message, "Missing")
}

///|
test "继承错误使用出错的辅助文件和对应代码" {
  let result = @generator.try_generate(
    "trait Child : Parent {}",
    "Child",
    filename="child.mbt",
    additional_sources=[("E:\\src\\parent.mbt", "\ntrait Parent : Missing {}")],
  )
  guard result is Err([error]) else { fail("应报告未找到祖先") }
  assert_eq(error.code, "supertrait_not_found")
  assert_eq(error.filename, "E:\\src\\parent.mbt")
  assert_eq(error.line, Some(2))
  assert_eq(error.column, Some(16))
  assert_eq(error.message, "Missing")
}

///|
test "结构化签名诊断与抛错接口使用同一条消息" {
  let file = "D:\\project\\api.mbt"
  let source = "trait Api {\n  fn run() -> Unit\n}"
  let result = @generator.try_generate(source, "Api", filename=file)
  guard result is Err([error]) else {
    fail("应拒绝缺失接收者的方法")
  }
  assert_eq(error.code, "unsupported_signature")
  assert_eq(error.filename, file)
  assert_eq(error.line, Some(2))
  assert_eq(error.column, Some(3))
  let legacy = Ok(@generator.generate(source, "Api", filename=file)) catch {
    @generator.GenerationError(message) => Err(message)
  }
  assert_true(legacy is Err(message) && message == error.text())
}

///|
test "类型名无效使用文件级诊断且先于解析" {
  let result = @generator.try_generate(
    "trait Api {",
    "Api",
    filename="api.mbt",
    mock_name="bad name",
  )
  guard result is Err([error]) else {
    fail("应报告无法使用的类型名")
  }
  assert_eq(error.code, "invalid_mock_name")
  assert_eq(error.line, None)
  assert_eq(error.column, None)
  assert_eq(error.filename, "api.mbt")
}

///|
test "结构化生成接口返回相同的生成源码" {
  let source = "trait Api { fn run(Self) -> Unit }"
  let result = @generator.try_generate(source, "Api", mock_name="Alternate")
  guard result is Ok(generated) else { fail("合法输入应生成源码") }
  assert_eq(
    generated,
    @generator.generate(source, "Api", mock_name="Alternate"),
  )
}
