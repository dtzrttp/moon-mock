///|
priv struct Payload {
  code : Int32
}

///|
test "Some 验证内部值且 None 不调用子谓词" {
  let visits : Array[Int32] = []
  let matcher = @matchers.some(
    @runtime.matching("为偶数", n => {
      visits.push(n)
      n % 2 == 0
    }),
  )
  assert_false(matcher.matches(None))
  assert_eq(visits, [])
  assert_true(matcher.matches(Some(8)))
  assert_false(matcher.matches(Some(3)))
  assert_eq(visits, [8, 3])
  assert_eq(matcher.description(), "Some（为偶数）")
}

///|
test "None 可匹配不支持 Eq 和 Debug 的载荷类型" {
  let matcher : @runtime.Matcher[Payload?] = @matchers.none()
  assert_true(matcher.matches(None))
  assert_false(matcher.matches(Some({ code: 0, })))
  assert_eq(matcher.description(), "None")
}

///|
test "Ok 只检查成功分支且可组合到 Option" {
  let matcher : @runtime.Matcher[Result[String?, Payload]] = @matchers.ok(
    @matchers.some(@matchers.ends_with(".txt")),
  )
  assert_true(matcher.matches(Ok(Some("说明.txt"))))
  assert_false(matcher.matches(Ok(Some("说明.jpg"))))
  assert_false(matcher.matches(Ok(None)))
  assert_false(matcher.matches(Err({ code: 2, })))
  assert_true(matcher.description().contains("Ok（Some（"))
  assert_true(matcher.description().contains(".txt"))
}

///|
test "Err 仅向失败分支传递载荷" {
  let visits : Array[Int32] = []
  let matcher : @runtime.Matcher[Result[String, Payload]] = @matchers.err(
    @runtime.matching("错误码大于 10", error => {
      visits.push(error.code)
      error.code > 10
    }),
  )
  assert_false(matcher.matches(Ok("成功")))
  assert_eq(visits, [])
  assert_false(matcher.matches(Err({ code: 10, })))
  assert_true(matcher.matches(Err({ code: 11, })))
  assert_eq(visits, [10, 11])
  assert_eq(matcher.description(), "Err（错误码大于 10）")
}

///|
test "嵌套变体保留每一层的存在和失败语义" {
  let matcher : @runtime.Matcher[Result[Int32?, String?]?] = @matchers.some(
    @matchers.err(@matchers.none()),
  )
  assert_true(matcher.matches(Some(Err(None))))
  assert_false(matcher.matches(None))
  assert_false(matcher.matches(Some(Err(Some("超时")))))
  assert_false(matcher.matches(Some(Ok(None))))
}

///|
test "捕获可以登记在变体外层并只消费成功选中的值" {
  let capture : @runtime.Capture[Int32?] = @runtime.Capture::new()
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Int32?, String] = @runtime.Method::new(
    controller, "Lookup",
  )
  slot.expect(capture.matcher(@matchers.some(@matchers.at_least(1))), "有值")
  assert_true(slot.try_take(None) is Err(_))
  assert_true(slot.try_take(Some(-1)) is Err(_))
  assert_eq(capture.values(), [])
  assert_true(slot.try_take(Some(3)) is Ok("有值"))
  assert_eq(capture.values(), [Some(3)])
  controller.verify()
}

///|
test "嵌套变体向实际选中的子匹配器转发捕获" {
  let good = @runtime.Capture::new()
  let bad = @runtime.Capture::new()
  let accepted : @runtime.Matcher[Result[Int32, String]?] = @matchers.some(
    @matchers.ok(good.matcher(@matchers.greater_than(0))).or_(
      @matchers.err(bad.matcher(@matchers.starts_with("已知错误"))),
    ),
  )
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Result[Int32, String]?, Unit] = @runtime.Method::new(
    controller, "Resolve",
  )
  slot.expect(accepted, (), times=2)
  assert_true(slot.try_take(Some(Ok(-1))) is Err(_))
  assert_true(slot.try_take(Some(Err("其他错误"))) is Err(_))
  assert_true(accepted.matches(Some(Ok(7))))
  assert_eq(good.values(), [])
  assert_eq(bad.values(), [])
  slot.take(Some(Ok(7)))
  assert_eq(good.values(), [7])
  assert_eq(bad.values(), [])
  slot.take(Some(Err("已知错误：超时")))
  assert_true(slot.try_take(Some(Ok(9))) is Err(_))
  assert_eq(good.values(), [7])
  assert_eq(bad.values(), ["已知错误：超时"])
  controller.verify()
}
