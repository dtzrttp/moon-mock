///|
priv struct Frame {
  kind : String
  offset : Int32
}

///|
test "逐位置匹配区分顺序、长度和重复项" {
  let matcher = @matchers.exact_elements([
    @matchers.less_than(0),
    @runtime.equal_to(3),
    @runtime.equal_to(3),
  ])
  assert_true(matcher.matches([-2, 3, 3]))
  assert_false(matcher.matches([3, 3, -2]))
  assert_false(matcher.matches([-2, 3]))
  assert_false(matcher.matches([-2, 3, 3, 3]))
  assert_false(matcher.matches([-2, 3, 4]))
  let empty : @runtime.Matcher[Array[Int32]] = @matchers.exact_elements([])
  assert_true(empty.matches([]))
  assert_false(empty.matches([0]))
}

///|
test "登记后改变原匹配器数组不会改变匹配行为或诊断" {
  let items = [@runtime.equal_to("数据")]
  let ordered = @matchers.exact_elements(items)
  guard @matchers.unordered_elements(items) is Ok(unordered) else {
    fail("单个子匹配器应构造成功")
  }
  let ordered_description = ordered.description()
  let unordered_description = unordered.description()
  items[0] = @runtime.equal_to("替换")
  items.push(@runtime.equal_to("追加"))
  for matcher in [ordered, unordered] {
    assert_true(matcher.matches(["数据"]))
    assert_false(matcher.matches(["替换"]))
    assert_false(matcher.matches(["替换", "追加"]))
  }
  assert_eq(ordered.description(), ordered_description)
  assert_eq(unordered.description(), unordered_description)
}

///|
test "逐位置匹配在长度不符或前面失败时短路" {
  let visits : Array[Int32] = []
  let first = @runtime.matching("负数", n => {
    visits.push(n)
    n < 0
  })
  let later = @runtime.matching("正数", n => {
    visits.push(n)
    n > 0
  })
  let matcher = @matchers.exact_elements([first, later])
  assert_false(matcher.matches([-1]))
  assert_eq(visits, [])
  assert_false(matcher.matches([1, 9]))
  assert_eq(visits, [1])
  visits.clear()
  assert_true(matcher.matches([-2, 4]))
  assert_eq(visits, [-2, 4])
}

///|
test "包含指定元素采用值相等且不会把子串当作元素" {
  let matcher = @matchers.contains_element("中")
  assert_true(matcher.matches(["中", "中"]))
  assert_true(matcher.matches(["中国", "中"]))
  assert_false(matcher.matches(["中国", "国中"]))
  assert_false(matcher.matches([]))
  assert_true(matcher.description().contains("中"))
}

///|
test "任一元素匹配在第一项成功时短路且空数组失败" {
  let visits : Array[Int32] = []
  let child = @runtime.matching("正数", n => {
    visits.push(n)
    n > 0
  })
  let matcher = @matchers.any_element(child)
  assert_false(matcher.matches([]))
  assert_eq(visits, [])
  assert_true(matcher.matches([-2, 7, 8]))
  assert_eq(visits, [-2, 7])
  visits.clear()
  assert_false(matcher.matches([-1, 0]))
  assert_eq(visits, [-1, 0])
}

///|
test "所有元素匹配在第一项失败时短路且空数组通过" {
  let visits : Array[Int32] = []
  let child = @runtime.matching("正数", n => {
    visits.push(n)
    n > 0
  })
  let matcher = @matchers.every_element(child)
  assert_true(matcher.matches([]))
  assert_eq(visits, [])
  assert_false(matcher.matches([1, 0, 3]))
  assert_eq(visits, [1, 0])
  visits.clear()
  assert_true(matcher.matches([1, 2]))
  assert_eq(visits, [1, 2])
}

///|
test "数组长度接受边界且与元素类型的 trait 无关" {
  let result : Result[@runtime.Matcher[Array[Frame]], @runtime.CallFailure] = @matchers.array_length_range(
    1, 2,
  )
  guard result is Ok(matcher) else { fail("有效长度区间应可构造") }
  let frame = { kind: "载荷", offset: 2, }
  assert_true(matcher.matches([frame]))
  assert_true(matcher.matches([frame, frame]))
  assert_false(matcher.matches([]))
  assert_false(matcher.matches([frame, frame, frame]))
  let zero_result : Result[@runtime.Matcher[Array[Frame]], @runtime.CallFailure] = @matchers.array_length_range(
    0, 0,
  )
  guard zero_result is Ok(empty) else { fail("零长度区间应可构造") }
  assert_true(empty.matches([]))
  assert_false(empty.matches([frame]))
}

///|
test "非法数组长度区间返回同类错误但说明领域" {
  for bounds in [(-2, -1), (-1, 2), (2, 1)] {
    let result : Result[@runtime.Matcher[Array[Unit]], @runtime.CallFailure] = @matchers.array_length_range(
      bounds.0,
      bounds.1,
    )
    guard result is Err(error) else {
      fail("非法数组长度区间应返回错误")
    }
    assert_eq(error.code, "invalid_range")
    assert_true(error.message.contains("数组长度"))
  }
}

///|
test "按索引投影支持泛型且越界时不访问子匹配器" {
  let visits : Array[String] = []
  let inner = @runtime.matching("指定帧类型", (frame : Frame) => {
    visits.push(frame.kind)
    frame.kind == "载荷" && frame.offset > 0
  })
  guard @matchers.element_at(1, inner) is Ok(matcher) else {
    fail("非负索引应可构造")
  }
  let header = { kind: "报头", offset: 0, }
  let payload = { kind: "载荷", offset: 1, }
  assert_false(matcher.matches([]))
  assert_false(matcher.matches([header]))
  assert_eq(visits, [])
  assert_true(matcher.matches([header, payload]))
  assert_false(matcher.matches([payload, header]))
  assert_eq(visits, ["载荷", "报头"])
}

///|
test "负索引构造受控失败且极大索引匹配小数组为假" {
  guard @matchers.element_at(-1, @runtime.equal_to(1)) is Err(error) else {
    fail("负索引应返回错误")
  }
  assert_eq(error.code, "invalid_index")
  assert_true(error.message.contains("-1"))
  guard @matchers.element_at(2_147_483_647, @runtime.equal_to(1)) is Ok(last) else {
    fail("应允许最大非负索引")
  }
  assert_false(last.matches([1]))
}

///|
test "所有元素和任一元素可在同一个领域数组上组合" {
  let valid = @matchers.at_least(0).project("偏移", (f : Frame) => f.offset)
  let payload = @runtime.equal_to("载荷").project("帧类型", (f : Frame) => {
    f.kind
  })
  let expected = @matchers.every_element(valid).and_(
    @matchers.any_element(payload),
  )
  assert_true(expected.matches([{ kind: "载荷", offset: 0, }]))
  assert_false(expected.matches([{ kind: "载荷", offset: -1, }]))
  assert_false(expected.matches([{ kind: "报头", offset: 0, }]))
  assert_false(expected.matches([]))
}

///|
test "任一元素只捕获最先通过的元素" {
  let capture = @runtime.Capture::new()
  let matcher = @matchers.any_element(
    capture.matcher(@matchers.greater_than(0)),
  )
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Array[Int32], Unit] = @runtime.Method::new(
    controller, "Filter",
  )
  slot.expect(matcher, (), times=2)
  assert_true(slot.try_take([-4, 0]) is Err(_))
  assert_true(matcher.matches([1, 2]))
  assert_eq(capture.values(), [])
  slot.take([-2, 7, 8])
  slot.take([4, 1])
  assert_true(slot.try_take([9]) is Err(_))
  assert_eq(capture.values(), [7, 4])
  controller.verify()
}

///|
test "每项捕获在数组完整匹配后才按数组顺序转发" {
  let capture = @runtime.Capture::new()
  let matcher = @matchers.every_element(capture.matcher(@matchers.at_least(0)))
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Array[Int32], Unit] = @runtime.Method::new(
    controller, "Scan",
  )
  slot.expect(matcher, (), times=2)
  assert_true(slot.try_take([3, -1, 7]) is Err(_))
  assert_eq(capture.values(), [])
  slot.take([])
  assert_eq(capture.values(), [])
  slot.take([3, 3, 1])
  assert_eq(capture.values(), [3, 3, 1])
  controller.verify()
}

///|
test "按位置和索引的内层捕获在被选中后各接收对应项" {
  let head = @runtime.Capture::new()
  let index = @runtime.Capture::new()
  let ordered = @matchers.exact_elements([
    head.matcher(@runtime.equal_to("报头")),
    @runtime.any(),
  ])
  guard @matchers.element_at(1, index.matcher(@matchers.starts_with("载荷")))
    is Ok(at_index) else {
    fail("有效索引应可构造")
  }
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Array[String], Unit] = @runtime.Method::new(
    controller, "Write",
  )
  slot.expect(ordered.and_(at_index), ())
  assert_true(slot.try_take(["报头", "无效"]) is Err(_))
  assert_eq(head.values(), [])
  assert_eq(index.values(), [])
  slot.take(["报头", "载荷 2"])
  assert_eq(head.values(), ["报头"])
  assert_eq(index.values(), ["载荷 2"])
  controller.verify()
}

///|
test "方法失败说明中显示数组预期的索引和实际长度" {
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Array[String], Unit] = @runtime.Method::new(
    controller, "Write",
  )
  guard @matchers.element_at(2, @matchers.ends_with(".json")) is Ok(matcher) else {
    fail("有效索引应可构造")
  }
  slot.expect(matcher, ())
  guard slot.try_take(["一项"]) is Err(error) else {
    fail("数组应匹配失败")
  }
  assert_eq(error.code, "argument_mismatch")
  assert_true(error.message.contains("索引 2"))
  assert_true(error.message.contains(".json"))
  assert_true(error.message.contains("长度为 1"))
  assert_eq(controller.snapshot()[0].seen, 0)
}

///|
test "数组子通知修改原数组时仍向其他子项交付已经选中的元素" {
  let constructors : Array[
    (@runtime.Matcher[Int32]) -> @runtime.Matcher[Array[Int32]],
  ] = [
    child => @matchers.exact_elements([child, child, child]),
    @matchers.every_element,
    child => {
      guard @matchers.unordered_elements([child, child, child]) is Ok(matcher) else {
        abort("三个匹配器应可构造")
      }
      matcher
    },
  ]
  for construct in constructors {
    let inputs = [1, 2, 3]
    let visited : Array[Int32] = []
    let child = @runtime.Matcher::custom("任意编号", _ => true, on_selected=value => {
      visited.push(value)
      if value == 1 {
        inputs[1] = 9
      }
    })
    let controller = @runtime.Controller::new()
    let slot : @runtime.Method[Array[Int32], Unit] = @runtime.Method::new(
      controller, "Write",
    )
    slot.expect(construct(child), ())
    slot.take(inputs)
    assert_eq(visited, [1, 2, 3])
    assert_eq(inputs, [1, 9, 3])
    controller.verify()
  }
}
