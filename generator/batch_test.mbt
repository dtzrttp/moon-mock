///|
fn batch_request(
  name : String,
  source~ : String = "trait Api { fn run(Self) -> Unit }",
  filename~ : String = "api.mbt",
  mock_name? : String,
  additional_sources~ : Array[(String, String)] = [],
) -> @generator.BatchRequest {
  { source, trait_name: name, filename, mock_name, additional_sources, }
}

///|
test "空批次通过预检并返回空结果" {
  @generator.validate_batch_requests([])
  assert_true(@generator.generate_batch([]).is_empty())
}

///|
test "单项失败保留原错误以及同批其他成功结果" {
  let requests = [
    batch_request("Api"),
    batch_request("Missing", filename="D:\\src\\missing.mbt"),
    batch_request(
      "Other",
      source="trait Other { async fn query(Self) -> String }",
    ),
  ]
  let results = @generator.generate_batch(requests)
  assert_eq(results.map(result => result.index), [0, 1, 2])
  assert_eq(results.map(result => result.trait_name), [
    "Api", "Missing", "Other",
  ])
  assert_eq(results[1].filename, "D:\\src\\missing.mbt")
  guard results[0] is { generated: Some(first), error: None, .. } else {
    fail("第一项应成功")
  }
  guard results[1] is { generated: None, error: Some(error), .. } else {
    fail("第二项应单独失败")
  }
  guard results[2] is { generated: Some(last), error: None, .. } else {
    fail("第三项应成功")
  }
  assert_true(first.contains("impl Api for MockApi"))
  assert_true(last.contains("impl Other for MockOther"))
  assert_eq(error, "D:\\src\\missing.mbt: trait_not_found: Missing")
}

///|
test "继承辅助源码的范围局限于对应的请求" {
  let source = "trait Child : Parent { fn stop(Self) -> Unit }"
  let one = batch_request("Child", source~, mock_name="FirstChild", additional_sources=[
    ("parent.mbt", "trait Parent { fn start(Self) -> Unit }"),
  ])
  let two = batch_request("Child", source~, mock_name="SecondChild")
  let results = @generator.generate_batch([one, two])
  guard results[0].generated is Some(output) else { fail("第一项应成功") }
  guard results[1].error is Some(error) else {
    fail("第二项应报告缺少父声明")
  }
  assert_true(output.contains("impl Parent for FirstChild with fn start"))
  assert_true(output.contains("impl Child for FirstChild with fn stop"))
  assert_true(error.contains("supertrait_not_found"))
  assert_true(error.contains("Parent"))
  let standalone = @generator.generate(
    one.source,
    one.trait_name,
    filename=one.filename,
    mock_name="FirstChild",
    additional_sources=one.additional_sources,
  )
  assert_eq(output, standalone)
}

///|
test "相同文件名的不同内容分别处理" {
  let requests = [
    batch_request("Api", mock_name="FirstApi"),
    batch_request(
      "Api",
      source="trait Api { fn stop(Self) -> Unit }",
      mock_name="SecondApi",
    ),
  ]
  let results = @generator.generate_batch(requests)
  guard results[0].generated is Some(first) else { fail("第一项应成功") }
  guard results[1].generated is Some(second) else { fail("第二项应成功") }
  assert_true(first.contains("impl Api for FirstApi with fn run"))
  assert_true(second.contains("impl Api for SecondApi with fn stop"))
  assert_false(second.contains("with fn run"))
}

///|
test "默认输出名和显式输出名冲突时整体拒绝" {
  let requests = [
    batch_request("Api", source="trait Api {", filename="first.mbt"),
    batch_request("Other", filename="second.mbt", mock_name="MockApi"),
  ]
  let checked = Ok(@generator.validate_batch_requests(requests)) catch {
    @generator.GenerationError(message) => Err(message)
  }
  let generated = Ok(@generator.generate_batch(requests)) catch {
    @generator.GenerationError(message) => Err(message)
  }
  guard checked is Err(message) else {
    fail("预检应拒绝重复的输出类型名")
  }
  assert_true(generated is Err(other) && other == message)
  assert_true(message.contains("duplicate_mock_name"))
  assert_true(message.contains("MockApi"))
  assert_true(message.contains("first.mbt"))
  assert_true(message.contains("second.mbt"))
}

///|
test "两个显式相同的输出类型名也冲突" {
  let checked = Ok(
    @generator.validate_batch_requests([
      batch_request("Api", mock_name="Shared"),
      batch_request("Other", mock_name="Shared"),
    ]),
  ) catch {
    @generator.GenerationError(message) => Err(message)
  }
  assert_true(
    checked is Err(message) && message.contains("duplicate_mock_name"),
  )
}

///|
test "无效输出名仍由对应请求报告" {
  let results = @generator.generate_batch([
    batch_request("First", mock_name="bad name"),
    batch_request("Api"),
    batch_request("Last", mock_name="bad name"),
  ])
  for index in [0, 2] {
    assert_true(results[index].generated is None)
    assert_true(
      results[index].error is Some(message) &&
      message.contains("invalid_mock_name"),
    )
  }
  assert_true(results[1].generated is Some(_))
}

///|
test "批次请求数量上限按边界预检" {
  let requests = Array::makei(@generator.MAX_BATCH_REQUESTS, index => {
    batch_request("Api", mock_name="Alternate" + index.to_string())
  })
  @generator.validate_batch_requests(requests)
  requests.push(batch_request("Api", mock_name="BeyondLimit"))
  let outcome = Ok(@generator.generate_batch(requests)) catch {
    @generator.GenerationError(message) => Err(message)
  }
  assert_true(outcome is Err(message) && message.contains("resource_limit"))
}

///|
test "批次可重复执行且先前结果不受请求数组修改影响" {
  let requests = [
    batch_request("Api"),
    batch_request("Broken", source="trait Broken {"),
  ]
  let first = @generator.generate_batch(requests)
  let second = @generator.generate_batch(requests)
  assert_eq(
    first.map(result => result.to_json()),
    second.map(result => result.to_json()),
  )
  requests[1] = batch_request(
    "Broken",
    source="trait Broken { fn repair(Self) -> Unit }",
  )
  let repaired = @generator.generate_batch(requests)
  assert_true(first[1].error is Some(_))
  assert_true(repaired[1].generated is Some(_))
  assert_eq(first[0].generated, repaired[0].generated)
}

///|
test "共享辅助源码时分别解析每个目标及其继承链" {
  let source =
    #|trait First : Parent { fn enqueue(Self) -> Unit }
    #|trait Second : Parent { fn flush(Self) -> Unit }
  let sources = [("parent.mbt", "trait Parent { fn run(Self) -> Unit }")]
  let requests = [
    batch_request("First", source~, additional_sources=sources),
    batch_request("Missing", source~, additional_sources=sources),
    batch_request("Second", source~, additional_sources=sources),
  ]
  let results = @generator.generate_batch(requests)
  for index in [0, 2] {
    let request = requests[index]
    let standalone = @generator.generate(
      request.source,
      request.trait_name,
      filename=request.filename,
      additional_sources=request.additional_sources,
    )
    assert_eq(results[index].generated, Some(standalone))
  }
  assert_eq(results[1].error, Some("api.mbt: trait_not_found: Missing"))
}

///|
test "主源码文本相同但文件名不同的请求各自保留方法位置" {
  let source = "trait Api {\n  fn run() -> Unit\n}"
  let results = @generator.generate_batch([
    batch_request("Api", source~, filename="first.mbt", mock_name="First"),
    batch_request("Api", source~, filename="second.mbt", mock_name="Second"),
  ])
  guard results[0].error is Some(first) else { fail("第一项应失败") }
  guard results[1].error is Some(second) else { fail("第二项应失败") }
  assert_true(first.has_prefix("first.mbt:2:3: unsupported_signature:"))
  assert_true(second.has_prefix("second.mbt:2:3: unsupported_signature:"))
}

///|
test "仅更换同名辅助文件的内容得到各自的生成结果" {
  let source = "trait Child : Parent {}"
  let results = @generator.generate_batch([
    batch_request("Child", source~, mock_name="First", additional_sources=[
      ("parent.mbt", "trait Parent { fn start(Self) -> Unit }"),
    ]),
    batch_request("Child", source~, mock_name="Second", additional_sources=[
      ("parent.mbt", "trait Parent { fn stop(Self) -> Unit }"),
    ]),
  ])
  guard results[0].generated is Some(first) else { fail("第一项应成功") }
  guard results[1].generated is Some(second) else { fail("第二项应成功") }
  assert_true(first.contains("impl Parent for First with fn start"))
  assert_true(second.contains("impl Parent for Second with fn stop"))
}

///|
test "辅助文件排列改变时重名诊断呈现本项的声明顺序" {
  let source = "trait Child : Parent {}"
  let one = ("first.mbt", "trait Parent { fn start(Self) -> Unit }")
  let two = ("second.mbt", "trait Parent { fn stop(Self) -> Unit }")
  let results = @generator.generate_batch([
    batch_request("Child", source~, mock_name="First", additional_sources=[
      one, two,
    ]),
    batch_request("Child", source~, mock_name="Second", additional_sources=[
      two, one,
    ]),
  ])
  guard results[0].error is Some(first) else {
    fail("第一项应报告重名")
  }
  guard results[1].error is Some(second) else {
    fail("第二项应报告重名")
  }
  assert_true(first.contains("first.mbt:1:7、second.mbt:1:7"))
  assert_true(second.contains("second.mbt:1:7、first.mbt:1:7"))
}

///|
test "批次重复源码的同时仍保留生成阶段原有的诊断优先顺序" {
  let source = "trait Present { fn read(Self) -> Unit }"
  let additional_sources = [("bad.mbt", "trait Unclosed {")]
  let results = @generator.generate_batch([
    batch_request("Present", source~, additional_sources~),
    batch_request("Missing", source~, additional_sources~),
    batch_request("Present", source~, mock_name="bad", additional_sources~),
  ])
  guard results[0].error is Some(parse_error) else {
    fail("辅助文件语法有误")
  }
  guard results[1].error is Some(missing) else { fail("主文件缺少目标") }
  guard results[2].error is Some(invalid) else { fail("显式类型名无效") }
  assert_true(parse_error.contains("bad.mbt:1:"))
  assert_true(parse_error.contains("parse_error"))
  assert_eq(missing, "api.mbt: trait_not_found: Missing")
  assert_true(invalid.has_prefix("api.mbt: invalid_mock_name:"))
}
