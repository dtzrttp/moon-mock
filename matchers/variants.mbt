///|
fn[A] option_variant(value : A?) -> String {
  match value {
    Some(_) => "Some"
    None => "None"
  }
}

///|
fn[A, E] result_variant(value : Result[A, E]) -> String {
  match value {
    Ok(_) => "Ok"
    Err(_) => "Err"
  }
}

///|
/// 匹配包含满足子匹配器的载荷的 `Some`。
pub fn[A] some(child : @runtime.Matcher[A]) -> @runtime.Matcher[A?] {
  select_child(
    "Some（\{child.description()}）",
    child,
    value => value,
    option_variant,
  )
}

///|
/// 匹配缺失的可选值 `None`。
pub fn[A] none() -> @runtime.Matcher[A?] {
  @runtime.Matcher::custom(
    "None",
    value => value is None,
    describe_actual=option_variant,
  )
}

///|
/// 匹配载荷符合子匹配器的成功结果 `Ok`。
pub fn[A, E] ok(child : @runtime.Matcher[A]) -> @runtime.Matcher[Result[A, E]] {
  select_child(
    "Ok（\{child.description()}）",
    child,
    value => {
      match value {
        Ok(item) => Some(item)
        Err(_) => None
      }
    },
    result_variant,
  )
}

///|
/// 匹配载荷符合子匹配器的失败结果 `Err`。
pub fn[A, E] err(child : @runtime.Matcher[E]) -> @runtime.Matcher[Result[A, E]] {
  select_child(
    "Err（\{child.description()}）",
    child,
    value => {
      match value {
        Ok(_) => None
        Err(error) => Some(error)
      }
    },
    result_variant,
  )
}
