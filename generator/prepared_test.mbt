///|
test "已准备源码可为同一文件内的多个 trait 反复发射" {
  let source =
    #|trait Parent { fn load(Self) -> Unit }
    #|trait First : Parent { fn open(Self) -> String }
    #|trait Second : Parent { fn close(Self) -> Unit }
  let prepared = @generator.prepare_sources(source, filename="services.mbt")
  let first = @generator.generate_prepared(prepared, "First")
  let second = @generator.generate_prepared(
    prepared,
    "Second",
    mock_name="Alternate",
  )
  assert_true(first.contains("impl Parent for MockFirst with fn load"))
  assert_true(first.contains("impl First for MockFirst with fn open"))
  assert_false(first.contains("with fn close"))
  assert_true(second.contains("impl Parent for Alternate with fn load"))
  assert_true(second.contains("impl Second for Alternate with fn close"))
  assert_false(second.contains("with fn open"))
  assert_eq(first, @generator.generate_prepared(prepared, "First"))
  assert_eq(first, @generator.generate(source, "First"))
  assert_eq(
    second,
    @generator.generate(source, "Second", mock_name="Alternate"),
  )
}

///|
test "只能以主文件中声明的 trait 为生成目标" {
  let source = "trait Child : Parent {}"
  let extra = [("parent.mbt", "trait Parent { fn start(Self) -> Unit }")]
  let prepared = @generator.prepare_sources(
    source,
    filename="child.mbt",
    additional_sources=extra,
  )
  let missing = Ok(@generator.generate_prepared(prepared, "Parent")) catch {
    @generator.GenerationError(message) => Err(message)
  }
  assert_true(missing is Err("child.mbt: trait_not_found: Parent"))
  let child = @generator.generate_prepared(prepared, "Child")
  assert_true(child.contains("impl Child for MockChild"))
  assert_true(child.contains("impl Parent for MockChild with fn start"))
}

///|
test "生成失败后可从同一份解析结果选择其他 trait" {
  let source =
    #|trait Left : Right {}
    #|trait Right : Left {}
    #|trait Unsupported { fn bad() -> Unit }
    #|trait Healthy { fn read(Self) -> Unit }
  let prepared = @generator.prepare_sources(source, filename="groups.mbt")
  for
    (name, code) in [
      ("Left", "trait_cycle"),
      ("Unsupported", "unsupported_signature"),
    ] {
    let checked = Ok(@generator.generate_prepared(prepared, name)) catch {
      @generator.GenerationError(message) => Err(message)
    }
    let baseline = Ok(@generator.generate(source, name, filename="groups.mbt")) catch {
      @generator.GenerationError(message) => Err(message)
    }
    assert_true(checked is Err(message) && message.contains(code))
    assert_eq(checked, baseline)
    let healthy = @generator.generate_prepared(prepared, "Healthy")
    assert_true(healthy.contains("impl Healthy for MockHealthy with fn read"))
  }
}

///|
test "修改辅助源码数组只影响随后重新准备的索引" {
  let primary = "trait Child : Parent {}"
  let sources = [("parent.mbt", "trait Parent { fn start(Self) -> Unit }")]
  let first = @generator.prepare_sources(primary, additional_sources=sources)
  sources[0] = ("parent.mbt", "trait Parent { fn stop(Self) -> Unit }")
  let second = @generator.prepare_sources(primary, additional_sources=sources)
  assert_true(
    @generator.generate_prepared(first, "Child").contains("with fn start"),
  )
  assert_true(
    @generator.generate_prepared(second, "Child").contains("with fn stop"),
  )
  assert_false(
    @generator.generate_prepared(first, "Child").contains("with fn stop"),
  )
}

///|
test "准备源码时标出辅助文件中尚未修复的语法错误" {
  let prepared = Ok(
    @generator.prepare_sources("trait Child {}", filename="child.mbt", additional_sources=[
      ("D:\\src\\parent.mbt", "\ntrait Parent {"),
    ]),
  ) catch {
    @generator.GenerationError(message) => Err(message)
  }
  guard prepared is Err(message) else {
    fail("应报告辅助文件语法错误")
  }
  assert_true(message.contains("D:\\src\\parent.mbt:2:"))
  assert_true(message.contains("parse_error"))
}

///|
test "准备后仍在生成时报告主文件与辅助文件的同名冲突" {
  let source = "trait Api { fn run(Self) -> Unit }"
  let additional_sources = [("E:\\secondary.mbt", "\ntrait Api {}")]
  let filename = "D:\\primary.mbt"
  let prepared = @generator.prepare_sources(
    source,
    filename~,
    additional_sources~,
  )
  let checked = Ok(@generator.generate_prepared(prepared, "Api")) catch {
    @generator.GenerationError(message) => Err(message)
  }
  let standalone = Ok(
    @generator.generate(source, "Api", filename~, additional_sources~),
  ) catch {
    @generator.GenerationError(message) => Err(message)
  }
  guard checked is Err(message) else {
    fail("应当报告重名的目标 trait")
  }
  assert_true(message.contains("ambiguous_trait"))
  assert_true(message.contains("D:\\primary.mbt:1:"))
  assert_true(message.contains("E:\\secondary.mbt:2:"))
  assert_eq(checked, standalone)
}

///|
test "已准备源码仍按照原规则检查自定义输出类型名" {
  let prepared = @generator.prepare_sources(
    "trait Api { fn read(Self) -> Unit }",
    filename="api.mbt",
  )
  let checked = Ok(
    @generator.generate_prepared(prepared, "Missing", mock_name="lower"),
  ) catch {
    @generator.GenerationError(message) => Err(message)
  }
  assert_true(
    checked is Err(message) && message.has_prefix("api.mbt: invalid_mock_name:"),
  )
}
