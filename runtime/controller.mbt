///|
pub struct Controller {
  priv tickets : Array[Ticket]
  priv mut closed : Bool
}

///|
priv struct Ticket {
  name : String
  description : String
  count : CallCount
  mut seen : Int32
}

///|
/// 创建互相隔离的一组预期。
pub fn Controller::new() -> Controller {
  { tickets: [], closed: false, }
}

///|
pub suberror VerificationError {
  VerificationFailed(String)
} derive(Debug)

///|
pub extend VerificationError with Debug::{to_repr}

///|
/// 列出尚未满足的调用次数，按预期登记顺序报告。
pub fn Controller::missing_calls(self : Controller) -> Array[String] {
  let missing = []
  for ticket in self.tickets {
    if ticket.seen < ticket.count.minimum {
      missing.push(
        "missing_calls: \{ticket.name}（\{ticket.description}）预期 \{ticket.count.describe()}，实际 \{ticket.seen} 次",
      )
    }
  }
  missing
}

///|
/// 如果存在尚未满足的预期，抛出可读的测试错误。
pub fn Controller::verify(self : Controller) -> Unit raise VerificationError {
  let missing = self.missing_calls()
  if !missing.is_empty() {
    raise VerificationFailed(missing.join("\n"))
  }
}

///|
/// 测试体正常返回时自动检查预期。测试体失败时原错误直接传播。
pub fn[T] with_mock(body : (Controller) -> T raise) -> T raise {
  let controller = Controller::new()
  defer {
    controller.closed = true
  }
  let result = body(controller)
  controller.verify()
  result
}

///|
/// 在异步测试体完成时自动检查。异步任务应在作用域内汇合。
pub async fn[T] with_mock_async(body : async (Controller) -> T) -> T {
  let controller = Controller::new()
  defer {
    controller.closed = true
  }
  let result = body(controller)
  controller.verify()
  result
}

///|
pub struct Sequence {
  priv tickets : Array[Ticket]
  priv mut cursor : Int32
}

///|
/// 组内预期按登记顺序匹配。独立顺序组可以交错执行。
pub fn Sequence::new() -> Sequence {
  { tickets: [], cursor: 0, }
}

///|
fn Sequence::blocking_message(self : Sequence, position : Int32) -> String? {
  if position < self.cursor {
    return Some(
      " 已越过顺序位置，当前步骤是 " +
      self.tickets[self.cursor].name,
    )
  }
  for i in self.cursor..<position {
    let prior = self.tickets[i]
    if prior.seen < prior.count.minimum {
      return Some(" 必须等待 " + prior.name)
    }
  }
  None
}
