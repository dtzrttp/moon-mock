///|
test "同名冲突定位两个文件中的声明" {
  let result = Ok(
    @generator.generate("trait Service : Left + Right {}", "Service", additional_sources=[
      ("left.mbt", "trait Left { fn read(Self) -> Unit }"),
      ("right.mbt", "\ntrait Right { fn read(Self) -> Unit }"),
    ]),
  ) catch {
    @generator.GenerationError(message) => Err(message)
  }
  guard result is Err(message) else { fail("应拒绝同名方法") }
  assert_true(message.contains("method_conflict"))
  assert_true(message.contains("left.mbt:1:"))
  assert_true(message.contains("right.mbt:2:"))
}

///|
test "继承深度超出资源边界时返回诊断" {
  let source = StringBuilder()
  for i in 0..<129 {
    source.write_string(
      "trait T" + i.to_string() + " : T" + (i + 1).to_string() + " {}\n",
    )
  }
  source.write_string("trait T129 { fn run(Self) -> Unit }")
  let result = Ok(@generator.generate(source.to_string(), "T0")) catch {
    @generator.GenerationError(message) => Err(message)
  }
  guard result is Err(message) else { fail("应报告继承深度上限") }
  assert_true(message.contains("resource_limit"))
}

///|
test "只扩展被选择的继承链，忽略无关的缺失依赖" {
  let source =
    #|trait Unrelated : Missing { fn run(Self) -> Unit }
    #|trait Selected { fn run(Self) -> Unit }
  let out = @generator.generate(source, "Selected")
  assert_true(out.contains("impl Selected for MockSelected"))
  assert_false(out.contains("Unrelated"))
}

///|
test "异常类型名不会作为源码插入输出" {
  for name in ["", "lower", "X\nimpl Bad", "X[Unit]", "X.foo", "X;"] {
    let rejected = Ok(
      @generator.generate(
        "trait Source { fn read(Self) -> Unit }",
        "Source",
        mock_name=name,
      ),
    ) catch {
      @generator.GenerationError(message) => Err(message)
    }
    assert_true(
      rejected is Err(message) && message.contains("invalid_mock_name"),
    )
  }
}

///|
test "递归类型签名的64层边界和超限定位" {
  for depth in [64, 65] {
    let mut typ = "Int32"
    for _ in 0..<depth {
      typ = "Array[" + typ + "]"
    }
    for
      signature in [
        "fn read(Self, " + typ + ") -> Unit",
        "fn read(Self) -> " + typ,
      ] {
      let result = Ok(
        @generator.generate(
          "trait Nested { " + signature + " }",
          "Nested",
          filename="nested.mbt",
        ),
      ) catch {
        @generator.GenerationError(message) => Err(message)
      }
      if depth == 64 {
        assert_true(result is Ok(_))
      } else {
        guard result is Err(message) else { fail("65层嵌套应被拒绝") }
        assert_true(message.contains("nested.mbt:1:"))
        assert_true(message.contains("resource_limit"))
      }
    }
  }
}

///|
test "嵌套函数和可选类型同样计入深度预算" {
  let mut typ = "Int32"
  for _ in 0..<33 {
    typ = "((Int32) -> " + typ + ")?"
  }
  let result = Ok(
    @generator.generate(
      "trait Nested { fn read(Self) -> " + typ + " }",
      "Nested",
    ),
  ) catch {
    @generator.GenerationError(message) => Err(message)
  }
  guard result is Err(message) else { fail("混合类型嵌套应被拒绝") }
  assert_true(message.contains("resource_limit"))
  let recovered = @generator.generate(
    "trait Good { fn read(Self) -> Int32 }", "Good",
  )
  assert_true(recovered.contains("struct MockGood"))
}
