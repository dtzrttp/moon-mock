///|
pub struct Matcher[A] {
  priv description : String
  priv accepts : (A) -> Bool
  priv describe_actual : ((A) -> String)?
  priv on_selected : ((A) -> Unit)?
}

///|
/// 定义参数谓词。谓词应无副作用，且不应再次调用同一 mock。
pub fn[A] matching(description : String, predicate : (A) -> Bool) -> Matcher[A] {
  { description, accepts: predicate, describe_actual: None, on_selected: None, }
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
    on_selected: None,
  }
}

///|
fn[A] Matcher::selected(self : Matcher[A], value : A) -> Unit {
  if self.on_selected is Some(notify) {
    notify(value)
  }
}

///|
fn[A] Matcher::renderer(
  self : Matcher[A],
  other : Matcher[A],
) -> ((A) -> String)? {
  match self.describe_actual {
    Some(_) => self.describe_actual
    None => other.describe_actual
  }
}

///|
/// 取交集。谓词从左向右短路，成功选中后通知两个匹配器。
pub fn[A] Matcher::and_(self : Matcher[A], other : Matcher[A]) -> Matcher[A] {
  {
    description: "(" + self.description + " 且 " + other.description + ")",
    accepts: value => (self.accepts)(value) && (other.accepts)(value),
    describe_actual: self.renderer(other),
    on_selected: Some(value => {
      self.selected(value)
      other.selected(value)
    }),
  }
}

///|
/// 取并集。两个分支都匹配时，只有左分支收到选中通知。
pub fn[A] Matcher::or_(self : Matcher[A], other : Matcher[A]) -> Matcher[A] {
  {
    description: "(" + self.description + " 或 " + other.description + ")",
    accepts: value => (self.accepts)(value) || (other.accepts)(value),
    describe_actual: self.renderer(other),
    on_selected: Some(value => {
      if (self.accepts)(value) {
        self.selected(value)
      } else {
        other.selected(value)
      }
    }),
  }
}

///|
/// 取反。否定匹配器成功时没有被肯定选中的参数。
pub fn[A] Matcher::not_(self : Matcher[A]) -> Matcher[A] {
  {
    description: "非（" + self.description + "）",
    accepts: value => !(self.accepts)(value),
    describe_actual: self.describe_actual,
    on_selected: None,
  }
}

///|
/// 将输入映射后交给匹配器。映射和谓词均应为无副作用的函数。
pub fn[A, B] Matcher::project(
  self : Matcher[A],
  label : String,
  extract : (B) -> A,
) -> Matcher[B] {
  {
    description: label + "：" + self.description,
    accepts: value => (self.accepts)(extract(value)),
    describe_actual: self.describe_actual.map(render => {
      value => render(extract(value))
    }),
    on_selected: Some(value => self.selected(extract(value))),
  }
}

///|
/// 匹配集合中的任意值。复制数组以固定登记时的成员。
pub fn[A : Eq + Debug] one_of(values : Array[A]) -> Matcher[A] {
  let expected = values.copy()
  {
    description: "属于 " + @debug.to_string(expected),
    accepts: value => expected.contains(value),
    describe_actual: Some(value => @debug.to_string(value)),
    on_selected: None,
  }
}
