///|
pub struct Method[A, F] {
  priv controller : Controller
  priv name : String
  priv rules : Array[Rule[A, F]]
}

///|
priv struct Rule[A, F] {
  matcher : Matcher[A]
  action : F
  ticket : Ticket
  order : (Sequence, Int32)?
}

///|
pub struct CallFailure {
  code : String
  message : String
}

///|
/// 创建一个类型化的方法预期列表。生成器为每个方法创建一个列表。
pub fn[A, F] Method::new(
  controller : Controller,
  name : String,
) -> Method[A, F] {
  { controller, name, rules: [], }
}

///|
/// 登记一次预期，`times` 默认为 1，可指定同一个顺序组。
pub fn[A, F] Method::expect(
  self : Method[A, F],
  matcher : Matcher[A],
  action : F,
  times~ : Int32 = 1,
  sequence? : Sequence,
) -> Unit {
  if self.controller.closed {
    abort("scope_closed: " + self.name)
  }
  if times < 0 {
    abort("invalid_count: " + self.name + " 的预期次数不能为负数")
  }
  let ticket = {
    name: self.name,
    description: matcher.description,
    times,
    seen: 0,
  }
  let order = match sequence {
    Some(group) => {
      let position = group.tickets.length()
      group.tickets.push(ticket)
      Some((group, position))
    }
    None => None
  }
  self.controller.tickets.push(ticket)
  self.rules.push({ matcher, action, ticket, order, })
}

///|
/// 在执行回调前选择预期并增加实际次数。
pub fn[A, F] Method::try_take(
  self : Method[A, F],
  args : A,
) -> Result[F, CallFailure] {
  if self.controller.closed {
    return Err({
      code: "scope_closed",
      message: self.name + " 的测试作用域已关闭",
    })
  }
  if self.rules.is_empty() {
    return Err({
      code: "unexpected_call",
      message: self.name + " 没有配置调用预期",
    })
  }
  let mut blocked : String? = None
  let mut exhausted : Ticket? = None
  let descriptions = []
  let mut actual = ""
  for rule in self.rules {
    if !(rule.matcher.accepts)(args) {
      descriptions.push(rule.matcher.description)
      if actual.is_empty() && rule.matcher.describe_actual is Some(render) {
        actual = "，实际参数 " + render(args)
      }
      continue
    }
    if rule.ticket.seen >= rule.ticket.times {
      exhausted = Some(rule.ticket)
      continue
    }
    if rule.order is Some((group, index)) && !group.ready(index) {
      blocked = Some(group.tickets[group.cursor].name)
      continue
    }
    rule.ticket.seen += 1
    return Ok(rule.action)
  }
  match (blocked, exhausted) {
    (Some(before), _) =>
      Err({
        code: "out_of_order",
        message: self.name + " 必须等待 " + before,
      })
    (None, Some(ticket)) =>
      Err({
        code: "too_many_calls",
        message: "\{self.name}（\{ticket.description}）已达到 \{ticket.times} 次上限",
      })
    _ =>
      Err({
        code: "argument_mismatch",
        message: self.name +
        " 的参数未匹配预期：" +
        descriptions.join("、") +
        actual,
      })
  }
}

///|
/// 未匹配调用会立即失败。保留 mock 对应 trait 的错误类型。
pub fn[A, F] Method::take(self : Method[A, F], args : A) -> F {
  match self.try_take(args) {
    Ok(action) => action
    Err(error) => abort(error.code + ": " + error.message)
  }
}
