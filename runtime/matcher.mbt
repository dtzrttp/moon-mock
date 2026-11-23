///|
pub struct Matcher[A] {
  priv description : String
  priv accepts : (A) -> Bool
  priv describe_actual : ((A) -> String)?
  priv prepare : (A, Selection) -> Unit
}

///|
/// 在调用回调前冻结捕获值和选中通知，避免回调修改参数影响后续捕获。
pub struct Selection {
  priv captures : Array[() -> Unit]
  priv notifications : Array[() -> Unit]
}

///|
pub fn Selection::new() -> Selection {
  { captures: [], notifications: [], }
}

///|
/// 延后写入捕获值，所有捕获完成后才运行用户通知。
pub fn Selection::capture(self : Selection, commit : () -> Unit) -> Unit {
  self.captures.push(commit)
}

///|
/// 依登记顺序排队通知。
pub fn Selection::notify(self : Selection, notification : () -> Unit) -> Unit {
  self.notifications.push(notification)
}

///|
/// 先提交完整捕获，再运行可能修改实参或重入 mock 的通知。
pub fn Selection::complete(self : Selection) -> Unit {
  for capture in self.captures {
    capture()
  }
  for notification in self.notifications {
    notification()
  }
}

///|
/// 创建可组合的匹配器。谓词和参数渲染应无副作用。
/// 选中通知在控制器完成次数和顺序检查后执行，可转发给实际选中的子匹配器。
pub fn[A] Matcher::custom(
  description : String,
  predicate : (A) -> Bool,
  describe_actual? : (A) -> String,
  on_selected? : (A) -> Unit,
) -> Matcher[A] {
  Matcher::compose(description, predicate, describe_actual, (value, selection) => {
    if on_selected is Some(callback) {
      selection.notify(() => callback(value))
    }
  })
}

///|
/// 构造能把子匹配器及捕获纳入同一次选中准备过程的组合匹配器。
/// `prepare` 只能读取选中值并排队工作，不应立即运行用户回调。
pub fn[A] Matcher::compose(
  description : String,
  predicate : (A) -> Bool,
  describe_actual : ((A) -> String)?,
  prepare : (A, Selection) -> Unit,
) -> Matcher[A] {
  { description, accepts: predicate, describe_actual, prepare, }
}

///|
/// 读取用于登记和失败诊断的说明。
pub fn[A] Matcher::description(self : Matcher[A]) -> String {
  self.description
}

///|
/// 仅检查谓词，不发送选中通知、不捕获参数。
pub fn[A] Matcher::matches(self : Matcher[A], value : A) -> Bool {
  (self.accepts)(value)
}

///|
/// 定义参数谓词。谓词应无副作用，且不应再次调用同一 mock。
pub fn[A] matching(description : String, predicate : (A) -> Bool) -> Matcher[A] {
  Matcher::custom(description, predicate)
}

///|
/// 接受任意参数。
pub fn[A] any() -> Matcher[A] {
  matching("任意参数", _ => true)
}

///|
/// 使用调用参数的 Eq 比较。
pub fn[A : Eq + Debug] equal_to(expected : A) -> Matcher[A] {
  Matcher::compose(
    "等于 " + @debug.to_string(expected),
    actual => actual == expected,
    Some(actual => @debug.to_string(actual)),
    (_, _) => (),
  )
}

///|
/// 将实际选中的值通知匹配器。组合器应在自身被选中后，仅向实际选中的子匹配器转发。
/// 此方法不再次检查谓词。
pub fn[A] Matcher::notify_selected(self : Matcher[A], value : A) -> Unit {
  let selection = Selection::new()
  (self.prepare)(value, selection)
  selection.complete()
}

///|
/// 在统一选择批次中递归准备子匹配器，回调在整个组合准备结束后才运行。
pub fn[A] Matcher::prepare_selected(
  self : Matcher[A],
  value : A,
  selection : Selection,
) -> Unit {
  (self.prepare)(value, selection)
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
  Matcher::compose(
    "(" + self.description + " 且 " + other.description + ")",
    value => self.matches(value) && other.matches(value),
    self.renderer(other),
    (value, selection) => {
      self.prepare_selected(value, selection)
      other.prepare_selected(value, selection)
    },
  )
}

///|
/// 取并集。两个分支都匹配时，只有左分支收到选中通知。
pub fn[A] Matcher::or_(self : Matcher[A], other : Matcher[A]) -> Matcher[A] {
  Matcher::compose(
    "(" + self.description + " 或 " + other.description + ")",
    value => self.matches(value) || other.matches(value),
    self.renderer(other),
    (value, selection) => {
      if self.matches(value) {
        self.prepare_selected(value, selection)
      } else {
        other.prepare_selected(value, selection)
      }
    },
  )
}

///|
/// 取反。否定匹配器成功时没有被肯定选中的参数。
pub fn[A] Matcher::not_(self : Matcher[A]) -> Matcher[A] {
  Matcher::compose(
    "非（" + self.description + "）",
    value => !self.matches(value),
    self.describe_actual,
    (_, _) => (),
  )
}

///|
/// 将输入映射后交给匹配器。映射和谓词均应为无副作用的函数。
pub fn[A, B] Matcher::project(
  self : Matcher[A],
  label : String,
  extract : (B) -> A,
) -> Matcher[B] {
  Matcher::compose(
    label + "：" + self.description,
    value => self.matches(extract(value)),
    self.describe_actual.map(render => value => render(extract(value))),
    (value, selection) => {
      let projected = extract(value)
      self.prepare_selected(projected, selection)
    },
  )
}

///|
/// 匹配集合中的任意值。复制数组以固定登记时的成员。
pub fn[A : Eq + Debug] one_of(values : Array[A]) -> Matcher[A] {
  let expected = values.copy()
  Matcher::compose(
    "属于 " + @debug.to_string(expected),
    value => expected.contains(value),
    Some(value => @debug.to_string(value)),
    (_, _) => (),
  )
}
