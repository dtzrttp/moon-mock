///|
fn[A] describe_array(actual : Array[A]) -> String {
  "数组长度为 \{actual.length()}"
}

///|
fn[A] describe_elements(children : Array[@runtime.Matcher[A]]) -> String {
  "[" + children.map(child => child.description()).join("，") + "]"
}

///|
/// 检查数组长度及每个位置的元素。构造时复制子匹配器数组。
pub fn[A] exact_elements(
  expected : Array[@runtime.Matcher[A]],
) -> @runtime.Matcher[Array[A]] {
  let children = expected.copy()
  @runtime.Matcher::compose(
    "按顺序匹配 \{describe_elements(children)}",
    actual => {
      if actual.length() != children.length() {
        return false
      }
      for index in 0..<children.length() {
        if !children[index].matches(actual[index]) {
          return false
        }
      }
      true
    },
    Some(describe_array),
    (actual, selection) => {
      let selected = actual.copy()
      for index in 0..<children.length() {
        children[index].prepare_selected(selected[index], selection)
      }
    },
  )
}

///|
fn[A] first_matching_element(
  actual : Array[A],
  child : @runtime.Matcher[A],
) -> A? {
  for item in actual {
    if child.matches(item) {
      return Some(item)
    }
  }
  None
}

///|
/// 检查数组中是否存在满足子匹配器的元素。转发通知给第一个匹配项。
pub fn[A] any_element(
  child : @runtime.Matcher[A],
) -> @runtime.Matcher[Array[A]] {
  @runtime.Matcher::compose(
    "至少一项满足（\{child.description()}）",
    actual => first_matching_element(actual, child) is Some(_),
    Some(describe_array),
    (actual, selection) => {
      if first_matching_element(actual, child) is Some(item) {
        child.prepare_selected(item, selection)
      }
    },
  )
}

///|
/// 检查数组是否包含与指定值相等的元素。
pub fn[A : Eq + Debug] contains_element(
  expected : A,
) -> @runtime.Matcher[Array[A]] {
  any_element(@runtime.equal_to(expected))
}

///|
/// 检查所有元素，空数组也匹配。调用被选中时依数组顺序转发通知。
pub fn[A] every_element(
  child : @runtime.Matcher[A],
) -> @runtime.Matcher[Array[A]] {
  @runtime.Matcher::compose(
    "每一项满足（\{child.description()}）",
    actual => actual.all(item => child.matches(item)),
    Some(describe_array),
    (actual, selection) => {
      let selected = actual.copy()
      for item in selected {
        child.prepare_selected(item, selection)
      }
    },
  )
}

///|
/// 匹配长度位于闭区间的数组。区间必须有序且非负。
pub fn[A] array_length_range(
  minimum : Int32,
  maximum : Int32,
) -> Result[@runtime.Matcher[Array[A]], @runtime.CallFailure] {
  validate_range("数组长度", minimum, maximum, nonnegative=true).map(_ => {
    @runtime.Matcher::custom(
      "数组长度在 \{interval_text(minimum, maximum)} 内",
      actual => in_range(actual.length(), minimum, maximum),
      describe_actual=describe_array,
    )
  })
}

///|
/// 检查零基索引处的元素。索引缺失时匹配失败，负索引返回 `invalid_index`。
pub fn[A] element_at(
  index : Int32,
  child : @runtime.Matcher[A],
) -> Result[@runtime.Matcher[Array[A]], @runtime.CallFailure] {
  if index < 0 {
    return Err(
      @runtime.CallFailure::new(
        "invalid_index",
        "数组索引必须非负，收到 \{index}",
      ),
    )
  }
  Ok(
    select_child(
      "数组索引 \{index} 的元素满足（\{child.description()}）",
      child,
      actual => actual.get(index),
      describe_array,
    ),
  )
}
