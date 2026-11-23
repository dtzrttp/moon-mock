///|
test "组合与投影匹配器用于多参数和领域对象" {
  let controller = @runtime.Controller::new()
  let positive = @runtime.matching("正数", (n : Int32) => n > 0)
  let small = @runtime.matching("小于10", (n : Int32) => n < 10)
  let accepted = positive.and_(small).or_(@runtime.equal_to(42))
  let slot : @runtime.Method[(String, Int32), String] = @runtime.Method::new(
    controller, "Search",
  )
  slot.expect(accepted.project("数量", pair => pair.1), "found", times=2)
  assert_true(slot.try_take(("a", 3)) is Ok("found"))
  assert_true(slot.try_take(("b", 42)) is Ok("found"))
  assert_true(slot.try_take(("c", -1)) is Err(_))
  controller.verify()
}

///|
test "捕获仅在次数和顺序检查成功后发生" {
  let capture : @runtime.Capture[String] = @runtime.Capture::new()
  let controller = @runtime.Controller::new()
  let sequence = @runtime.Sequence::new()
  let first : @runtime.Method[Unit, Unit] = @runtime.Method::new(
    controller, "first",
  )
  let slot : @runtime.Method[String, Unit] = @runtime.Method::new(
    controller, "next",
  )
  first.expect(@runtime.any(), (), sequence~)
  slot.expect(capture.matcher(@runtime.equal_to("ok")), (), sequence~)
  assert_true(slot.try_take("ok") is Err(_))
  assert_true(slot.try_take("wrong") is Err(_))
  assert_eq(capture.values(), [])
  first.take(())
  slot.take("ok")
  assert_eq(capture.values(), ["ok"])
  assert_true(slot.try_take("ok") is Err(_))
  assert_eq(capture.values(), ["ok"])
  let copy = capture.values()
  copy.push("修改副本")
  assert_eq(capture.values(), ["ok"])
}

///|
test "或匹配器只通知实际选中的分支，否定不捕获参数" {
  let left : @runtime.Capture[Int32] = @runtime.Capture::new()
  let right : @runtime.Capture[Int32] = @runtime.Capture::new()
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Int32, Unit] = @runtime.Method::new(
    controller, "choose",
  )
  slot.expect(
    left.matcher(@runtime.any()).or_(right.matcher(@runtime.any())),
    (),
  )
  slot.take(7)
  assert_eq(left.values(), [7])
  assert_eq(right.values(), [])
  slot.expect(left.matcher(@runtime.equal_to(0)).not_(), ())
  slot.take(9)
  assert_eq(left.values(), [7])
}

///|
test "集合匹配器覆盖空集合、重复项及 Unicode" {
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[String, Int32] = @runtime.Method::new(
    controller, "locale",
  )
  slot.expect(@runtime.one_of(["中文", "中文", "日本語"]), 1, times=2)
  slot.expect(@runtime.one_of([]), 2, times=0)
  assert_true(slot.try_take("中文") is Ok(1))
  assert_true(slot.try_take("日本語") is Ok(1))
  assert_true(slot.try_take("") is Err(_))
  controller.verify()
}

///|
test "公开匹配检查读取说明且不会启动选中通知" {
  let captured : @runtime.Capture[Int32] = @runtime.Capture::new()
  let matcher = captured.matcher(@runtime.matching("正值", n => n > 0))
  assert_true(matcher.description().contains("正值"))
  assert_true(matcher.matches(7))
  assert_false(matcher.matches(-3))
  assert_true(captured.values().is_empty())
}

///|
test "自定义组合可将实际选中通知转发给子匹配器" {
  let captured : @runtime.Capture[Int32] = @runtime.Capture::new()
  let child = captured.matcher(@runtime.matching("至少三件", n => n >= 3))
  let matcher : @runtime.Matcher[(String, Int32)] = @runtime.Matcher::custom(
    "数量 " + child.description(),
    pair => child.matches(pair.1),
    describe_actual=pair => "数量=\{pair.1}",
    on_selected=pair => child.notify_selected(pair.1),
  )
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[(String, Int32), Unit] = @runtime.Method::new(
    controller, "order",
  )
  slot.expect(matcher, ())
  guard slot.try_take(("large", 1)) is Err(error) else {
    fail("不合格的订单错误地通过匹配")
  }
  assert_true(error.message.contains("数量=1"))
  assert_eq(captured.values(), [])
  slot.take(("large", 4))
  assert_true(slot.try_take(("large", 9)) is Err(_))
  assert_eq(captured.values(), [4])
  controller.verify()
}

///|
test "兄弟通知改写输入前投影已经准备并记录捕获" {
  let captured : @runtime.Capture[Int32] = @runtime.Capture::new()
  let before_mutation = Ref([])
  let left : @runtime.Matcher[Array[Int32]] = @runtime.Matcher::custom(
    "修改首项",
    _ => true,
    on_selected=items => {
      before_mutation.val = captured.values()
      items[0] = 99
    },
  )
  let right = captured
    .matcher(@runtime.equal_to(1))
    .project("首项", (items : Array[Int32]) => items[0])
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Array[Int32], Unit] = @runtime.Method::new(
    controller, "mutable_projection",
  )
  slot.expect(left.and_(right), ())
  let items = [1]
  slot.take(items)
  assert_eq(captured.values(), [1])
  assert_eq(before_mutation.val, [1])
  assert_eq(items, [99])
  controller.verify()
}

///|
test "兄弟通知改写输入前或组合已决定获选的分支" {
  let preferred : @runtime.Capture[Int32] = @runtime.Capture::new()
  let fallback : @runtime.Capture[Int32] = @runtime.Capture::new()
  let left : @runtime.Matcher[Array[Int32]] = @runtime.Matcher::custom(
    "改写",
    _ => true,
    on_selected=items => items[0] = 9,
  )
  let either = preferred
    .matcher(@runtime.equal_to(1))
    .or_(fallback.matcher(@runtime.any()))
  let right = either.project("第一项", (items : Array[Int32]) => items[0])
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Array[Int32], Unit] = @runtime.Method::new(
    controller, "mutable_disjunction",
  )
  slot.expect(left.and_(right), ())
  slot.take([1])
  assert_eq(preferred.values(), [1])
  assert_true(fallback.values().is_empty())
  controller.verify()
}

///|
test "选中通知重入时捕获顺序与调用历史一致" {
  let captured : @runtime.Capture[Int32] = @runtime.Capture::new()
  let controller = history_controller(2)
  let slot : @runtime.Method[Int32, Unit] = @runtime.Method::new(
    controller, "reentry",
  )
  let listener = @runtime.Matcher::custom("重入通知", _ => true, on_selected=value => {
    if value == 1 {
      slot.take(2)
    }
  })
  slot.expect(captured.matcher(listener), (), times=2)
  slot.take(1)
  assert_eq(controller.history().map(event => event.ordinal), [1L, 2L])
  assert_eq(captured.values(), [1, 2])
  controller.verify()
}
