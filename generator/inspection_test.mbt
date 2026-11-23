///|
test "检查空源码和没有 trait 的源码" {
  assert_true(@generator.inspect_source("").is_empty())
  assert_true(
    @generator.inspect_source("fn name() -> String { \"无 trait\" }").is_empty(),
  )
}

///|
test "保留所有 trait 声明的源码顺序和同名声明" {
  let source =
    #|struct Record { value : Int }
    #|trait Z接口 {}
    #|trait Alpha {}
    #|trait Z接口 {}
  let traits = @generator.inspect_source(source, filename="api.mbt")
  assert_eq(traits.map(info => info.name), ["Z接口", "Alpha", "Z接口"])
  assert_eq(traits.map(info => info.file), ["api.mbt", "api.mbt", "api.mbt"])
  assert_eq(traits.map(info => info.line), [2, 3, 4])
  assert_eq(traits.map(info => info.column), [1, 1, 1])
}

///|
test "保留父 trait 的限定名以及声明顺序" {
  let traits = @generator.inspect_source(
    "trait Service : Local + @net.Connection + Missing {}",
  )
  assert_eq(traits[0].parents, ["Local", "@net.Connection", "Missing"])
  assert_eq(traits[0].file, "<stdin>")
  assert_true(traits[0].methods.is_empty())
}

///|
test "检查 Unicode 方法以及参数、异步和默认实现标记" {
  let source =
    #|trait Api {
    #|  fn 读取(Self, String, retries? : Int) -> String = _
    #|  async fn write(Self) -> Unit noraise
    #|  fn factory() -> Int
    #|}
  let traits = @generator.inspect_source(source)
  let methods = traits[0].methods
  assert_eq(methods.map(info => info.name), ["读取", "write", "factory"])
  assert_eq(methods.map(info => info.parameter_count), [3, 1, 0])
  assert_eq(methods.map(info => info.line), [2, 3, 4])
  assert_eq(methods.map(info => info.column), [3, 3, 3])
  assert_eq(methods.map(info => info.async_), [false, true, false])
  assert_eq(methods.map(info => info.has_default), [true, false, false])
}

///|
test "独立检查的源码各自保留 Windows 文件名和换行位置" {
  let first = @generator.inspect_source(
      "// 文档\r\n\r\n  trait First { fn run(Self) -> Unit }",
      filename="D:\\工作区\\first.mbt",
    )[0]
  let second = @generator.inspect_source(
      "// 文档\ntrait Second {\n    fn stop(Self) -> Unit\n}",
      filename="E:\\另一目录\\second.mbt",
    )[0]
  assert_eq(
    (first.file, first.line, first.column),
    ("D:\\工作区\\first.mbt", 3, 3),
  )
  assert_eq(
    (second.file, second.line, second.column),
    ("E:\\另一目录\\second.mbt", 2, 1),
  )
  assert_eq((first.methods[0].line, first.methods[0].column), (3, 17))
  assert_eq((second.methods[0].line, second.methods[0].column), (3, 5))
}

///|
test "无法解析时拒绝返回解析器恢复出的部分 trait" {
  let outcome = Ok(
    @generator.inspect_source(
      "trait Valid {}\ntrait Broken { fn read(Self) -> }",
      filename="D:\\workspace\\bad.mbt",
    ),
  ) catch {
    @generator.GenerationError(message) => Err(message)
  }
  guard outcome is Err(message) else { fail("应要求先修正语法") }
  assert_true(message.contains("D:\\workspace\\bad.mbt:2:"))
  assert_true(message.contains("parse_error"))
}

///|
test "检查接口按解析器顺序返回多条结构化语法诊断" {
  let file = "D:\\项目:模块\\bad.mbt"
  let source =
    #|trait Valid {}
    #|trait BadFirst { fn read(Self) -> }
    #|trait BadSecond { fn write(Self) -> }
  let checked = @generator.try_inspect_source(source, filename=file)
  guard checked is Err(diagnostics) else { fail("应报告语法诊断") }
  assert_eq(diagnostics.map(issue => issue.code), ["parse_error", "parse_error"])
  assert_eq(diagnostics.map(issue => issue.filename), [file, file])
  assert_eq(diagnostics.map(issue => issue.line), [Some(2), Some(3)])
  let text = diagnostics.map(issue => issue.text()).join("\n")
  let legacy = Ok(@generator.inspect_source(source, filename=file)) catch {
    @generator.GenerationError(message) => Err(message)
  }
  assert_true(legacy is Err(message) && message == text)
}

///|
test "结构化检查和原检查返回相同的声明信息" {
  let source =
    #|trait A {}
    #|trait Z : @io.Base {
    #|  async fn run(Self, limit? : Int) -> Unit = _
    #|}
  let previous = @generator.inspect_source(source, filename="source.mbt")
  let checked = @generator.try_inspect_source(source, filename="source.mbt")
  guard checked is Ok(traits) else { fail("合法语法应通过检查") }
  assert_eq(
    traits.map(info => info.to_json()),
    previous.map(info => info.to_json()),
  )
}
