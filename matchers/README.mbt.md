# Moon Mock 参数匹配器

在 `moon.pkg` 中导入 `"dtzrttp/moon-mock/matchers"`，即可用 `@matchers` 构造 `@runtime.Matcher[A]`。把它传给生成代码的预期登记方法，或用运行库的 `and_`、`or_`、`not_` 和 `project` 组合。

| 参数类型 | 匹配器 | 行为 |
| --- | --- | --- |
| `String` | `starts_with`、`ends_with`、`contains_text` | 按原始文本、区分大小写。空文本匹配任意字符串。 |
| `String` | `text_length_range` | Unicode 码点数的非负闭区间。`😀` 算一个码点，`e` 加组合重音算两个。 |
| `Int32` | `int_range`、`less_than`、`at_most`、`greater_than`、`at_least` | 闭区间或单边比较，覆盖 `Int32` 极值。 |
| `Option[A]` | `some`、`none` | 检查是否存在值，存在时可用子匹配器检查载荷。 |
| `Result[A, E]` | `ok`、`err` | 检查成功或失败分支的载荷。 |
| `Array[A]` | `exact_elements`、`unordered_elements` | 检查等长的逐项匹配。无序版本为每个子匹配器分配一个独立位置。 |
| `Array[A]` | `contains_element`、`any_element`、`every_element` | 检查值相等、至少一个子匹配或全部子匹配。空数组只满足全部元素语义。 |
| `Array[A]` | `array_length_range`、`element_at` | 检查非负闭区间长度，或读取零基索引上的值。 |
| `(A, B)` | `first`、`second`、`pair` | 匹配一项或两项，两项组合从左到右短路。 |

`int_range`、`text_length_range`、`array_length_range` 的非法区间返回 `invalid_range`。`element_at` 接受任意非负索引，实际数组缺少相应位置时匹配失败，负索引返回 `invalid_index`。`unordered_elements` 支持至多 128 个子匹配器，超出时返回 `too_many_elements`。`unordered_elements` 和 `exact_elements` 构造时复制子匹配器数组。

## 组合请求参数

把元组的第一项作为路径，第二项作为可选标签。路径有固定前缀，标签至少包含两个码点，并且不能全部是空白。

```mbt check
///|
test "路径和可选标签组合" {
  guard @matchers.text_length_range(2, 12) is Ok(tag_length) else {
    fail("标签长度区间无效")
  }
  let has_content = @runtime.matching("包含非空白字符", (tag : String) => {
    tag.trim().length() > 0
  })
  let incoming = @matchers.pair(
    @matchers.starts_with("/orders/"),
    @matchers.some(tag_length.and_(has_content)),
  )
  assert_true(incoming.matches(("/orders/42", Some("待审"))))
  assert_false(incoming.matches(("/orders/42", Some("  "))))
  assert_false(incoming.matches(("/orders/42", None)))
  assert_false(incoming.matches(("/invoices/42", Some("待审"))))
}
```

## 捕获通过验证的元素

`matches` 只运行谓词。控制器实际选中预期时，组合匹配器会向选中的子项转发捕获。`any_element` 在数组中从前向后寻找，并捕获首个通过的元素。`every_element` 在全部元素通过后，按数组顺序逐项捕获。`unordered_elements` 按子匹配器顺序转发确定的配对结果。逐项转发前会浅复制实参数组，固定这次通知中的各项引用。

```mbt check
///|
test "捕获首个通过的商品编号" {
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[Array[String], Unit] = @runtime.Method::new(
    controller, "Reserve",
  )
  let codes = @runtime.Capture::new()
  let sku = codes.matcher(@matchers.starts_with("SKU-"))
  slot.expect(@matchers.any_element(sku), ())
  assert_true(slot.try_take(["备注", "链接"]) is Err(_))
  assert_eq(codes.values(), [])
  slot.take(["备注", "SKU-44", "SKU-56"])
  assert_eq(codes.values(), ["SKU-44"])
  controller.verify()
}
```

数组、变体和元组支持嵌套。例如 `exact_elements([some(first(child))])` 接受包含一个可选元组的数组，匹配 `Some` 元组的第一项。所有子谓词应为纯函数。无序配对和捕获转发可能重新执行谓词。
