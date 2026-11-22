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
