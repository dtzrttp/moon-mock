///|
test "元组两项投影可组合且支持不同的类型" {
  let expected = @matchers.first(@matchers.starts_with("出库")).and_(
    @matchers.second(@matchers.greater_than(0)),
  )
  assert_true(expected.matches(("出库单", 1)))
  assert_false(expected.matches(("入库单", 1)))
  assert_false(expected.matches(("出库单", -1)))
  assert_true(expected.description().contains("第一项"))
  assert_true(expected.description().contains("第二项"))
}

///|
test "元组合成按左后右进行短路匹配" {
  let visits : Array[String] = []
  let name = @runtime.matching("库位", (value : String) => {
    visits.push(value)
    value == "库位"
  })
  let active = @runtime.matching("启用", (value : Bool) => {
    visits.push(if value { "启用" } else { "禁用" })
    value
  })
  let matcher = @matchers.pair(name, active)
  assert_false(matcher.matches(("仓库", true)))
  assert_eq(visits, ["仓库"])
  visits.clear()
  assert_false(matcher.matches(("库位", false)))
  assert_eq(visits, ["库位", "禁用"])
  visits.clear()
  assert_true(matcher.matches(("库位", true)))
  assert_eq(visits, ["库位", "启用"])
}

///|
test "元组捕获转发到两项并遵守没有选中时的次数约束" {
  let names = @runtime.Capture::new()
  let counts = @runtime.Capture::new()
  let matcher = @matchers.pair(
    names.matcher(@matchers.starts_with("卷")),
    counts.matcher(@matchers.at_least(0)),
  )
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[(String, Int32), Int32] = @runtime.Method::new(
    controller, "Transfer",
  )
  slot.expect(matcher, 3)
  assert_true(slot.try_take(("卷 A", -1)) is Err(_))
  assert_eq(names.values(), [])
  assert_eq(counts.values(), [])
  assert_true(slot.try_take(("卷 A", 2)) is Ok(3))
  assert_true(slot.try_take(("卷 B", 5)) is Err(_))
  assert_eq(names.values(), ["卷 A"])
  assert_eq(counts.values(), [2])
  controller.verify()
}

///|
test "元组可作为变体与数组匹配器的元素类型" {
  let fields = @matchers.pair(
    @runtime.equal_to("成功"),
    @matchers.some(@matchers.at_most(9)),
  )
  let matcher = @matchers.exact_elements([
    fields,
    @matchers.second(@matchers.none()),
  ])
  assert_true(matcher.matches([("成功", Some(2)), ("空缺", None)]))
  assert_false(matcher.matches([("跳过", Some(2)), ("空缺", None)]))
  assert_false(matcher.matches([("成功", Some(9)), ("空缺", Some(1))]))
}
