///|
test "多层超 trait 各实现一次，共用祖先不重复生成" {
  let source =
    #|trait Readable { fn read(Self, Int32) -> String }
    #|trait Snapshot : Readable { fn snapshot(Self) -> String }
    #|trait Live : Readable { fn refresh(Self) -> Unit raise }
    #|trait Store : Snapshot + Live { fn close(Self) -> Unit }
  let generated = @generator.generate(source, "Store")
  assert_true(generated.contains("impl Readable for MockStore with fn read"))
  assert_true(
    generated.contains("impl Snapshot for MockStore with fn snapshot"),
  )
  assert_true(generated.contains("impl Live for MockStore with fn refresh"))
  assert_true(generated.contains("impl Store for MockStore with fn close"))
  assert_eq(generated.split("slot_read :").count(), 2)
  assert_true(generated.contains("Readable.read"))
  assert_true(generated.contains("Live.refresh"))
  assert_eq(generated, @generator.generate(source, "Store"))
}

///|
test "由同包其他文件提供超 trait 声明" {
  let source = "trait Top : Middle { fn finish(Self) -> Unit }"
  let generated = @generator.generate(source, "Top", filename="top.mbt", additional_sources=[
    ("base.mbt", "trait Base { fn start(Self) -> Unit }"),
    ("middle.mbt", "trait Middle : Base {}"),
  ])
  assert_true(generated.contains("impl Base for MockTop with fn start"))
  assert_true(generated.contains("impl Middle for MockTop"))
  assert_true(generated.contains("impl Top for MockTop with fn finish"))
}

///|
test "根 trait 只有继承方法时生成显式实现" {
  let source =
    #|trait Marker {}
    #|trait Parent { fn run(Self) -> Unit }
    #|trait Child : Parent + Marker {}
  let output = @generator.generate(source, "Child")
  assert_true(output.contains("impl Child for MockChild"))
  assert_true(output.contains("impl Parent for MockChild with fn run"))
  assert_true(output.contains("impl Marker for MockChild"))
}

///|
test "无效继承时报错并保留来源" {
  for
    (source, expected) in [
      ("trait Top : Missing {}", "supertrait_not_found"),
      ("trait Top : @external.Base {}", "unsupported_signature"),
      ("trait Top : Top {}", "Top -> Top"),
      (
        "trait Top : Middle {}\ntrait Middle : Base {}\ntrait Base : Top {}", "Top -> Middle -> Base -> Top",
      ),
      (
        "trait Top : A + B {}\ntrait A { fn f(Self) -> Unit }\ntrait B { fn f(Self) -> Unit }",
        "method_conflict",
      ),
      (
        "trait Top : A {}\ntrait A { fn f(Self) -> Unit }\ntrait A { fn g(Self) -> Unit }",
        "ambiguous_trait",
      ),
      ("trait Top : Marker {}\ntrait Marker {}", "unsupported_signature"),
    ] {
    let result = Ok(@generator.generate(source, "Top", filename="traits.mbt")) catch {
      @generator.GenerationError(message) => Err(message)
    }
    guard result is Err(message) else { fail("应拒绝输入：" + source) }
    assert_true(message.contains("traits.mbt:"))
    assert_true(message.contains(expected))
  }
}

///|
test "跨文件错误使用声明所在文件和行号" {
  let result = Ok(
    @generator.generate("trait Top : Parent {}", "Top", filename="top.mbt", additional_sources=[
      ("parent.mbt", "\ntrait Parent : Missing {}"),
    ]),
  ) catch {
    @generator.GenerationError(message) => Err(message)
  }
  guard result is Err(message) else { fail("应报告缺少超 trait") }
  assert_true(message.contains("parent.mbt:2:"))
  assert_true(message.contains("Missing"))
}

///|
test "辅助文件解析错误保留其文件名" {
  let result = Ok(
    @generator.generate(
      "trait Top { fn run(Self) -> Unit }",
      "Top",
      filename="top.mbt",
      additional_sources=[("broken.mbt", "trait Parent {")],
    ),
  ) catch {
    @generator.GenerationError(message) => Err(message)
  }
  guard result is Err(message) else {
    fail("应报告辅助文件语法错误")
  }
  assert_true(message.contains("broken.mbt:"))
  assert_true(message.contains("parse_error"))
}
