///|
test "前缀匹配区分位置和大小写" {
  let matcher = @matchers.starts_with("订单-😀")
  assert_true(matcher.matches("订单-😀"))
  assert_true(matcher.matches("订单-😀-已付款"))
  assert_false(matcher.matches("旧订单-😀"))
  assert_false(matcher.matches("订单-"))
  assert_false(@matchers.starts_with("GET").matches("get /orders"))
}

///|
test "后缀匹配保留尾部空白和 Unicode" {
  let matcher = @matchers.ends_with(".账单")
  assert_true(matcher.matches("销售.账单"))
  assert_false(matcher.matches("销售.账单.bak"))
  assert_false(matcher.matches("销售.账单 "))
  assert_false(matcher.matches("销售"))
}

///|
test "子串匹配要求连续且保留原始编码" {
  assert_true(
    @matchers.contains_text("咖啡😀").matches("一杯咖啡😀！"),
  )
  assert_false(@matchers.contains_text("咖啡😀").matches("咖啡，😀"))
  assert_false(@matchers.contains_text("é").matches("e\u0301"))
  assert_true(@matchers.contains_text("\n").matches("第一行\n第二行"))
}

///|
test "空字符串同时是任意文本的前缀、后缀和子串" {
  for input in ["", "纯文本", "😀"] {
    assert_true(@matchers.starts_with("").matches(input))
    assert_true(@matchers.ends_with("").matches(input))
    assert_true(@matchers.contains_text("").matches(input))
  }
  assert_false(@matchers.starts_with("x").matches(""))
  assert_false(@matchers.ends_with("x").matches(""))
  assert_false(@matchers.contains_text("x").matches(""))
}

///|
test "文本长度区间按 Unicode 码点计数并包含边界" {
  guard @matchers.text_length_range(1, 3) is Ok(matcher) else {
    fail("有序的非负长度区间应可构造")
  }
  assert_true(matcher.matches("😀"))
  assert_true(matcher.matches("界😀e"))
  assert_true(matcher.matches("e\u0301"))
  assert_false(matcher.matches(""))
  assert_false(matcher.matches("界😀e\u0301"))
}

///|
test "文本长度的零边界和组合字符数量可区分" {
  guard @matchers.text_length_range(0, 0) is Ok(empty) else {
    fail("零长度区间应可构造")
  }
  guard @matchers.text_length_range(1, 1) is Ok(single) else {
    fail("单个码点的区间应可构造")
  }
  assert_true(empty.matches(""))
  assert_false(empty.matches("\u0301"))
  assert_true(single.matches("é"))
  assert_false(single.matches("e\u0301"))
}

///|
test "非法文本长度区间给出稳定的错误码和中文说明" {
  for bounds in [(-1, 2), (0, -1), (3, 2)] {
    guard @matchers.text_length_range(bounds.0, bounds.1) is Err(error) else {
      fail("非法文本长度区间应返回错误")
    }
    assert_eq(error.code, "invalid_range")
    assert_true(error.message.contains("文本长度"))
    assert_true(error.message.contains(bounds.0.to_string().view()))
    assert_true(error.message.contains(bounds.1.to_string().view()))
  }
}

///|
test "整数闭区间接受两端以及负数和零" {
  guard @matchers.int_range(-7, 2) is Ok(matcher) else {
    fail("有效整数区间应可构造")
  }
  for accepted in [-7, -1, 0, 2] {
    assert_true(matcher.matches(accepted))
  }
  assert_false(matcher.matches(-8))
  assert_false(matcher.matches(3))
  assert_eq(matcher.description(), "整数在 [-7, 2] 内")
}

///|
test "整数区间覆盖 Int32 极值而不会溢出" {
  let minimum = -2_147_483_648
  let maximum = 2_147_483_647
  guard @matchers.int_range(minimum, maximum) is Ok(full) else {
    fail("应允许 Int32 全范围")
  }
  guard @matchers.int_range(minimum, minimum) is Ok(single) else {
    fail("应允许只有下限的点区间")
  }
  assert_true(full.matches(minimum))
  assert_true(full.matches(maximum))
  assert_true(single.matches(minimum))
  assert_false(single.matches(minimum + 1))
  guard @matchers.int_range(maximum, minimum) is Err(error) else {
    fail("倒序区间应返回错误")
  }
  assert_eq(error.code, "invalid_range")
  assert_true(error.message.contains("整数"))
}

///|
test "比较匹配器区分严格和含等号的边界" {
  let bound = -4
  let cases = [
    (bound - 1, true, true, false, false),
    (bound, false, true, false, true),
    (bound + 1, false, false, true, true),
  ]
  for item in cases {
    assert_eq(@matchers.less_than(bound).matches(item.0), item.1)
    assert_eq(@matchers.at_most(bound).matches(item.0), item.2)
    assert_eq(@matchers.greater_than(bound).matches(item.0), item.3)
    assert_eq(@matchers.at_least(bound).matches(item.0), item.4)
  }
}

///|
test "比较匹配器保留 Int32 极值的严格语义" {
  let minimum = -2_147_483_648
  let maximum = 2_147_483_647
  assert_false(@matchers.less_than(minimum).matches(minimum))
  assert_false(@matchers.greater_than(maximum).matches(maximum))
  assert_true(@matchers.at_most(maximum).matches(minimum))
  assert_true(@matchers.at_least(minimum).matches(maximum))
}

///|
test "文本匹配器的描述转义换行以便诊断" {
  let matcher = @matchers.starts_with("GET\n")
  assert_true(matcher.description().contains("以 "))
  assert_true(matcher.description().contains("GET"))
  assert_false(matcher.description().contains("\n"))
}
