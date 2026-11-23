///|
test "无序数组允许排列且保留重复项个数" {
  guard @matchers.unordered_elements([
      @runtime.equal_to("甲"),
      @runtime.equal_to("甲"),
      @runtime.equal_to("乙"),
    ])
    is Ok(matcher) else {
    fail("三个匹配器应可构造")
  }
  assert_true(matcher.matches(["乙", "甲", "甲"]))
  assert_true(matcher.matches(["甲", "乙", "甲"]))
  assert_false(matcher.matches(["乙", "甲", "乙"]))
  assert_false(matcher.matches(["甲", "乙"]))
  assert_false(matcher.matches(["甲", "乙", "甲", "甲"]))
  assert_true(matcher.description().contains("无序"))
  assert_true(matcher.description().contains("甲"))
}

///|
test "无序匹配重新分配宽松匹配器占用的元素" {
  guard @matchers.unordered_elements([
      @runtime.any(),
      @runtime.equal_to(7),
      @matchers.at_most(0),
    ])
    is Ok(matcher) else {
    fail("三个匹配器应可构造")
  }
  assert_true(matcher.matches([7, -2, 10]))
  assert_true(matcher.matches([-2, 7, 10]))
  assert_false(matcher.matches([7, 10, 11]))
}

///|
test "无序匹配可沿多级增广路径重新分配" {
  let first = @runtime.one_of([1, 2])
  let second = @runtime.one_of([2, 3])
  let third = @runtime.one_of([3, 4])
  guard @matchers.unordered_elements([
      first,
      second,
      third,
      @runtime.equal_to(1),
    ])
    is Ok(matcher) else {
    fail("四个匹配器应可构造")
  }
  assert_true(matcher.matches([1, 2, 3, 4]))
  assert_false(matcher.matches([1, 2, 2, 2]))
}

///|
test "无序匹配的空数组语义和构造上限明确" {
  let result : Result[@runtime.Matcher[Array[Int32]], @runtime.CallFailure] = @matchers.unordered_elements([],
  )
  guard result is Ok(empty) else { fail("空匹配器数组应可构造") }
  assert_true(empty.matches([]))
  assert_false(empty.matches([0]))
  let widest = Array::make(128, @runtime.equal_to(0))
  guard @matchers.unordered_elements(widest) is Ok(boundary) else {
    fail("128 项构造应可接受")
  }
  assert_true(boundary.matches(Array::make(128, 0)))
  assert_false(boundary.matches(Array::make(129, 0)))
  widest.push(@runtime.any())
  guard @matchers.unordered_elements(widest) is Err(error) else {
    fail("超过构造上限应受控失败")
  }
  assert_eq(error.code, "too_many_elements")
  assert_true(error.message.contains("128"))
  assert_true(error.message.contains("129"))
}

///|
test "无序匹配失败不捕获且成功通知最终配对的元素" {
  let flexible = @runtime.Capture::new()
  let exact = @runtime.Capture::new()
  let small = @runtime.Capture::new()
  guard @matchers.unordered_elements([
      flexible.matcher(@runtime.any()),
      exact.matcher(@runtime.equal_to(7)),
      small.matcher(@matchers.at_most(0)),
    ])
    is Ok(matcher) else {
    fail("三个匹配器应可构造")
  }
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Array[Int32], Unit] = @runtime.Method::new(
    controller, "Allocate",
  )
  slot.expect(matcher, ())
  assert_true(slot.try_take([7, 1, 2]) is Err(_))
  assert_true(matcher.matches([7, -2, 10]))
  assert_eq(flexible.values(), [])
  assert_eq(exact.values(), [])
  assert_eq(small.values(), [])
  slot.take([7, -2, 10])
  assert_true(slot.try_take([-9, 7, 20]) is Err(_))
  assert_eq(flexible.values(), [10])
  assert_eq(exact.values(), [7])
  assert_eq(small.values(), [-2])
  controller.verify()
}

///|
test "多种无序配对同样有效时按固定顺序捕获" {
  let captures : Array[@runtime.Capture[Int32]] = Array::makei(3, _ => {
    @runtime.Capture::new()
  })
  guard @matchers.unordered_elements(
      captures.map(capture => capture.matcher(@runtime.any())),
    )
    is Ok(matcher) else {
    fail("三个匹配器应可构造")
  }
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Array[Int32], Unit] = @runtime.Method::new(
    controller, "Allocate",
  )
  slot.expect(matcher, (), times=2)
  slot.take([7, 3, 11])
  slot.take([7, 3, 11])
  assert_eq(captures[0].values(), [7, 7])
  assert_eq(captures[1].values(), [3, 3])
  assert_eq(captures[2].values(), [11, 11])
  controller.verify()
}

///|
// 独立参考实现枚举所有可用的位置分配，只用于小规模组合验证。
fn brute_assignment(
  masks : Array[Int32],
  values : Array[Int32],
  index : Int32,
  used : Int32,
) -> Bool {
  if index == masks.length() {
    return true
  }
  for pos in 0..<values.length() {
    let pos_flag = 1 << pos
    let value_flag = 1 << values[pos]
    if (used & pos_flag) == 0 &&
      (masks[index] & value_flag) != 0 &&
      brute_assignment(masks, values, index + 1, used | pos_flag) {
      return true
    }
  }
  false
}

///|
test "无序匹配与三元素有限域的穷举配对模型一致" {
  // 每个子匹配器都可以接受三种值的任意子集，数组允许相同值重复。
  for encoded_masks in 0..<512 {
    let masks = [encoded_masks % 8, encoded_masks / 8 % 8, encoded_masks / 64]
    let children = masks.map(mask => {
      @runtime.matching("测试值子集", value => (mask & (1 << value)) != 0)
    })
    guard @matchers.unordered_elements(children) is Ok(matcher) else {
      fail("三个匹配器应可构造")
    }
    for encoded_values in 0..<27 {
      let values = [
        encoded_values % 3,
        encoded_values / 3 % 3,
        encoded_values / 9,
      ]
      assert_eq(matcher.matches(values), brute_assignment(masks, values, 0, 0))
    }
  }
}

///|
test "无序匹配与不同长度随机输入的参考模型一致" {
  let rng = @random.Rand::chacha8(seed=b"0123456789abcdef0123456789abcdef")
  for size in 4..<=7 {
    for sample in 0..<80 {
      let values = Array::makei(size, _ => rng.int(limit=6))
      let masks = Array::makei(size, _ => rng.int(limit=64))
      if sample % 2 == 0 {
        // 为一半样本显式保留一个解，防止随机约束产生过少的成功路径。
        for index in 0..<size {
          masks[index] = masks[index] | (1 << values[index])
        }
        rng.shuffle(size, (left, right) => {
          let saved = values[left]
          values[left] = values[right]
          values[right] = saved
        })
      }
      let children = masks.map(mask => {
        @runtime.matching("测试值子集", value => (mask & (1 << value)) != 0)
      })
      guard @matchers.unordered_elements(children) is Ok(matcher) else {
        fail("测试规模应在构造上限之内")
      }
      let reference = brute_assignment(masks, values, 0, 0)
      if matcher.matches(values) != reference {
        fail(
          "长度 \{size} 的样本 \{sample} 与参考配对结果不一致",
        )
      }
    }
  }
}
