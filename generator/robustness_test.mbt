///|
test "96种签名组合均可确定性生成或返回来源诊断" {
  let params = [
    "Int32", "String?", "Array[(String, Int32)]", "&Cursor", "(Int32) -> String",
    "async (String) -> Int32 raise ReadError",
  ]
  let returns = ["Unit", "Int32?", "Array[String]", "() -> String"]
  for async_ in [false, true] {
    for label in ["", "value~ : "] {
      for arg in params {
        for result in returns {
          let prefix = if async_ { "async " } else { "" }
          let source = "trait Source { " +
            prefix +
            "fn run(Self, " +
            label +
            "(" +
            arg +
            ")) -> (" +
            result +
            ") }"
          let out = @generator.generate(source, "Source")
          assert_eq(out, @generator.generate(source, "Source"))
          assert_true(out.contains("expect_run"))
          assert_true(out.contains("respond_run"))
        }
      }
    }
  }
}

///|
test "60种损坏输入返回诊断且不会影响下一次生成" {
  let mutations = [
    "trait Source {", "trait Source { fn run(Self, ) -> }", "trait Source { fn run() -> Unit }",
    "trait Source : Source {}", "trait Source { fn run(Self) -> Self }", "trait Source { fn[A] run(Self, A) -> A }",
  ]
  for round in 0..<10 {
    for broken in mutations {
      let source = "// 固定变更 " + round.to_string() + "\n" + broken
      let result = Ok(
        @generator.generate(source, "Source", filename="mutation.mbt"),
      ) catch {
        @generator.GenerationError(message) => Err(message)
      }
      assert_true(result is Err(message) && message.contains("mutation.mbt:"))
      let valid = @generator.generate(
        "trait Source { fn run(Self) -> Unit }", "Source",
      )
      assert_true(valid.contains("impl Source for MockSource"))
    }
  }
}

///|
test "辅助文件排列和声明位置不影响菱形继承的输出" {
  let source = "trait Root : A + B {}"
  let a = ("a.mbt", "trait A : Base { fn a(Self) -> Unit }")
  let b = ("b.mbt", "trait B : Base { fn b(Self) -> Unit }")
  let base = ("base.mbt", "trait Base { fn read(Self) -> String }")
  let expected = @generator.generate(source, "Root", additional_sources=[
    a, b, base,
  ])
  for files in [[base, a, b], [b, base, a], [a, base, b], [b, a, base]] {
    assert_eq(
      @generator.generate(source, "Root", additional_sources=files),
      expected,
    )
  }
}
