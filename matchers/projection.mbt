///|
// 先对输入安全投影，存在子值时才执行谓词或转发选中通知。
fn[A, B] select_child(
  description : String,
  child : @runtime.Matcher[A],
  extract : (B) -> A?,
  describe_actual : (B) -> String,
) -> @runtime.Matcher[B] {
  @runtime.Matcher::compose(
    description,
    value => {
      match extract(value) {
        Some(item) => child.matches(item)
        None => false
      }
    },
    Some(describe_actual),
    (value, selection) => {
      if extract(value) is Some(item) {
        child.prepare_selected(item, selection)
      }
    },
  )
}

///|
/// 用子匹配器检查二元组的第一项。
pub fn[A, B] first(child : @runtime.Matcher[A]) -> @runtime.Matcher[(A, B)] {
  child.project("第一项", value => value.0)
}

///|
/// 用子匹配器检查二元组的第二项。
pub fn[A, B] second(child : @runtime.Matcher[B]) -> @runtime.Matcher[(A, B)] {
  child.project("第二项", value => value.1)
}

///|
/// 依次检查二元组的两项。调用被选中时按同样顺序转发通知。
pub fn[A, B] pair(
  left : @runtime.Matcher[A],
  right : @runtime.Matcher[B],
) -> @runtime.Matcher[(A, B)] {
  first(left).and_(second(right))
}
