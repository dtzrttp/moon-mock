///|
pub struct Matcher[A] {
  priv description : String
  priv accepts : (A) -> Bool
  priv describe_actual : ((A) -> String)?
}

///|
/// 定义参数谓词。谓词应无副作用，且不应再次调用同一 mock。
pub fn[A] matching(description : String, predicate : (A) -> Bool) -> Matcher[A] {
  { description, accepts: predicate, describe_actual: None, }
}

///|
/// 接受任意参数。
pub fn[A] any() -> Matcher[A] {
  matching("任意参数", _ => true)
}

///|
/// 使用调用参数的 Eq 比较。
pub fn[A : Eq + Debug] equal_to(expected : A) -> Matcher[A] {
  {
    description: "等于 " + @debug.to_string(expected),
    accepts: actual => actual == expected,
    describe_actual: Some(actual => @debug.to_string(actual)),
  }
}
