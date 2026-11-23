///|
/// 匹配以指定文本开头的字符串。空前缀匹配所有字符串。
pub fn starts_with(prefix : String) -> @runtime.Matcher[String] {
  @runtime.Matcher::custom(
    "以 \{@debug.to_string(prefix)} 开头",
    value => value.has_prefix(prefix.view()),
    describe_actual=@debug.to_string,
  )
}

///|
/// 匹配以指定文本结尾的字符串。空后缀匹配所有字符串。
pub fn ends_with(suffix : String) -> @runtime.Matcher[String] {
  @runtime.Matcher::custom(
    "以 \{@debug.to_string(suffix)} 结尾",
    value => value.has_suffix(suffix.view()),
    describe_actual=@debug.to_string,
  )
}

///|
/// 匹配包含指定连续文本的字符串。按原始文本比较并区分大小写。
pub fn contains_text(text : String) -> @runtime.Matcher[String] {
  @runtime.Matcher::custom(
    "包含子串 \{@debug.to_string(text)}",
    value => value.contains(text.view()),
    describe_actual=@debug.to_string,
  )
}

///|
/// 匹配 Unicode 码点数位于闭区间的字符串。区间必须有序且非负。
pub fn text_length_range(
  minimum : Int32,
  maximum : Int32,
) -> Result[@runtime.Matcher[String], @runtime.CallFailure] {
  validate_range("文本长度", minimum, maximum, nonnegative=true).map(_ => {
    @runtime.Matcher::custom(
      "文本码点数在 \{interval_text(minimum, maximum)} 内",
      value => in_range(value.iter().count(), minimum, maximum),
      describe_actual=value => "文本码点数为 \{value.iter().count()}",
    )
  })
}

///|
fn integer_matching(
  description : String,
  predicate : (Int32) -> Bool,
) -> @runtime.Matcher[Int32] {
  @runtime.Matcher::custom(description, predicate, describe_actual=value => {
    value.to_string()
  })
}

///|
/// 匹配位于闭区间的 Int32。上限小于下限时返回 `invalid_range`。
pub fn int_range(
  minimum : Int32,
  maximum : Int32,
) -> Result[@runtime.Matcher[Int32], @runtime.CallFailure] {
  validate_range("整数区间", minimum, maximum).map(_ => {
    integer_matching("整数在 \{interval_text(minimum, maximum)} 内", value => {
      in_range(value, minimum, maximum)
    })
  })
}

///|
/// 匹配严格小于指定上限的整数。
pub fn less_than(maximum : Int32) -> @runtime.Matcher[Int32] {
  integer_matching("整数小于 \{maximum}", value => value < maximum)
}

///|
/// 匹配小于或等于指定上限的整数。
pub fn at_most(maximum : Int32) -> @runtime.Matcher[Int32] {
  integer_matching("整数至多为 \{maximum}", value => value <= maximum)
}

///|
/// 匹配严格大于指定下限的整数。
pub fn greater_than(minimum : Int32) -> @runtime.Matcher[Int32] {
  integer_matching("整数大于 \{minimum}", value => value > minimum)
}

///|
/// 匹配大于或等于指定下限的整数。
pub fn at_least(minimum : Int32) -> @runtime.Matcher[Int32] {
  integer_matching("整数至少为 \{minimum}", value => value >= minimum)
}
