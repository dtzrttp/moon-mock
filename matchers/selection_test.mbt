///|
test "交集左侧通知改写数组时右侧仍捕获已选中的元素" {
  let captured = @runtime.Capture::new()
  let seen_before_change : Array[Int32] = []
  let changes = @runtime.Matcher::custom(
    "修改已处理的参数",
    _ => true,
    on_selected=(actual : Array[Int32]) => {
      for value in captured.values() {
        seen_before_change.push(value)
      }
      actual[0] = 99
    },
  )
  let ordered = @matchers.exact_elements([
    captured.matcher(@runtime.equal_to(1)),
  ])
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Array[Int32], Unit] = @runtime.Method::new(
    controller, "Store",
  )
  slot.expect(changes.and_(ordered), ())
  let actual = [1]
  slot.take(actual)
  assert_eq(seen_before_change, [1])
  assert_eq(captured.values(), [1])
  assert_eq(actual, [99])
  controller.verify()
}

///|
priv struct SelectionEnvelope {
  payload : Result[Array[Int32], String]?
}

///|
test "元组共享数组在左项清空前完成右项投影及变体内索引准备" {
  let captured = @runtime.Capture::new()
  let left = @runtime.Matcher::custom("清空左项数组", _ => true, on_selected=(
    actual : Array[Int32],
  ) => actual.clear())
  guard @matchers.element_at(1, captured.matcher(@runtime.equal_to(2)))
    is Ok(indexed) else {
    fail("索引应可构造")
  }
  let right = @matchers.some(@matchers.ok(indexed)).project("载荷", (
    item : SelectionEnvelope,
  ) => item.payload)
  let expected = @matchers.pair(left, right)
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[(Array[Int32], SelectionEnvelope), Unit] = @runtime.Method::new(
    controller, "Decode",
  )
  slot.expect(expected, ())
  let actual = [1, 2]
  assert_true(
    slot.try_take((actual, { payload: Some(Err("无载荷")), })) is Err(_),
  )
  assert_eq(actual, [1, 2])
  assert_eq(captured.values(), [])
  slot.take((actual, { payload: Some(Ok(actual)), }))
  assert_eq(actual, [])
  assert_eq(captured.values(), [2])
  controller.verify()
}

///|
test "变体中的并集和任一元素只转发原先选中的分支与位置" {
  let primary = @runtime.Capture::new()
  let fallback = @runtime.Capture::new()
  let rewrite = @runtime.Matcher::custom(
    "改写原数组的所有元素",
    _ => true,
    on_selected=(actual : Array[Int32]) => actual.fill(9),
  )
  let primary_element = @matchers.any_element(
    primary.matcher(@runtime.equal_to(1)),
  )
  let fallback_elements = @matchers.every_element(
    fallback.matcher(@runtime.equal_to(9)),
  )
  let nested = @matchers.some(
    rewrite.and_(primary_element.or_(fallback_elements)),
  )
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Array[Int32]?, Unit] = @runtime.Method::new(
    controller, "Choose",
  )
  slot.expect(nested, ())
  let actual = [0, 1, 3]
  slot.take(Some(actual))
  assert_eq(actual, [9, 9, 9])
  assert_eq(primary.values(), [1])
  assert_eq(fallback.values(), [])
  controller.verify()
}

///|
test "无序匹配在第一条通知重入前捕获外层配对且保持调用进入顺序" {
  let flexible = @runtime.Capture::new()
  let fixed = @runtime.Capture::new()
  let listener_values : Array[Int32] = []
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Array[Int32], Unit] = @runtime.Method::new(
    controller, "Allocate",
  )
  let listener = @runtime.Matcher::custom("记录输入并重入", _ => true, on_selected=(
    actual : Array[Int32],
  ) => {
    listener_values.push(actual[1])
    if actual[1] == 1 {
      actual.clear()
      slot.take([7, 2])
    }
  })
  guard @matchers.unordered_elements([
      flexible.matcher(@runtime.any()),
      fixed.matcher(@runtime.equal_to(7)),
    ])
    is Ok(assignment) else {
    fail("无序匹配应可构造")
  }
  slot.expect(listener.and_(assignment), (), times=2)
  let original = [7, 1]
  slot.take(original)
  assert_eq(original, [])
  assert_eq(listener_values, [1, 2])
  assert_eq(flexible.values(), [1, 2])
  assert_eq(fixed.values(), [7, 7])
  controller.verify()
}
