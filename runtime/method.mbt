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
/// 登记预期。默认调用一次，也可用 count 指定调用次数约束。
pub fn[A, F] Method::expect(
  self : Method[A, F],
  matcher : Matcher[A],
  action : F,
  times~ : Int32 = 1,
  sequence? : Sequence,
  count? : CallCount,
) -> Unit {
  match self.try_expect(matcher, action, times~, sequence?, count?) {
    Ok(_) => ()
    Err(error) => abort(error.code + ": " + error.message)
  }
}

///|
/// 登记失败时返回诊断，控制器和顺序组保持原状。
pub fn[A, F] Method::try_expect(
  self : Method[A, F],
  matcher : Matcher[A],
  action : F,
  times~ : Int32 = 1,
  sequence? : Sequence,
  count? : CallCount,
) -> Result[Unit, CallFailure] {
  if self.controller.closed {
    return Err({
      code: "scope_closed",
      message: self.name + " 的测试作用域已关闭",
    })
  }
  if times < 0 {
    return Err({
      code: "invalid_count",
      message: self.name + " 的预期次数不能为负数",
    })
  }
  if count is Some(_) && times != 1 {
    return Err({
      code: "invalid_count",
      message: self.name +
      " 同时设置了次数范围和非默认精确次数",
    })
  }
  if sequence is Some(group) &&
    group.owner is Some(owner) &&
    !physical_equal(owner, self.controller) {
    return Err({
      code: "sequence_controller_mismatch",
      message: self.name + " 的顺序组已属于另一个控制器",
    })
  }
  let ticket = {
    name: self.name,
    description: matcher.description,
    count: count.unwrap_or(CallCount::exact(times)),
    seen: 0,
  }
  let order = match sequence {
    Some(group) => {
      group.owner = Some(self.controller)
      let position = group.tickets.length()
      group.tickets.push(ticket)
      Some((group, position))
    }
    None => None
  }
  self.controller.tickets.push(ticket)
  self.rules.push({ matcher, action, ticket, order, })
  Ok(())
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
  let mut exhausted : (Ticket, Int32)? = None
  let descriptions = []
  let mut actual_renderer : ((A) -> String)? = None
  for rule in self.rules {
    if !(rule.matcher.accepts)(args) {
      descriptions.push(rule.matcher.description)
      if actual_renderer is None {
        actual_renderer = rule.matcher.describe_actual
      }
      continue
    }
    if rule.ticket.count.maximum is Some(maximum) && rule.ticket.seen >= maximum {
      exhausted = Some((rule.ticket, maximum))
      continue
    }
    if rule.order is Some((group, index)) {
      if group.blocking_message(index) is Some(reason) {
        blocked = Some(reason)
        continue
      }
      group.cursor = index
    }
    if rule.ticket.seen < 2147483647 {
      rule.ticket.seen += 1
    }
    rule.matcher.selected(args)
    return Ok(rule.action)
  }
  match (blocked, exhausted) {
    (Some(reason), _) =>
      Err({ code: "out_of_order", message: self.name + reason, })
    (None, Some((ticket, maximum))) =>
      Err({
        code: "too_many_calls",
        message: "\{self.name}（\{ticket.description}）已达到 \{maximum} 次上限",
      })
    _ => {
      let actual = match actual_renderer {
        Some(render) => "，实际参数 " + render(args)
        None => ""
      }
      Err({
        code: "argument_mismatch",
        message: self.name +
        " 的参数未匹配预期：" +
        descriptions.join("、") +
        actual,
      })
    }
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
