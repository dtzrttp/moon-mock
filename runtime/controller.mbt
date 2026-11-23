///|
pub struct Controller {
  priv tickets : Array[Ticket]
  priv mut closed : Bool
  priv history_buffer : CallHistory?
}

///|
priv struct Ticket {
  name : String
  index : Int32
  description : String
  count : CallCount
  mut seen : Int32
}

///|
/// 创建互相隔离的一组预期。
pub fn Controller::new() -> Controller {
  { tickets: [], closed: false, history_buffer: None, }
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
  Controller::new().run_scope(body)
}

///|
/// 启用有界调用历史，并在同步测试体完成后自动核对并关闭作用域。
/// 历史容量无效时抛出 `HistoryConfigError`，测试体不会执行。
pub fn[T] with_mock_history(
  capacity : Int32,
  body : (Controller) -> T raise,
) -> T raise {
  history_scope_controller(capacity).run_scope(body)
}

///|
fn[T] Controller::run_scope(
  self : Controller,
  body : (Controller) -> T raise,
) -> T raise {
  defer {
    self.closed = true
  }
  let result = body(self)
  self.verify()
  result
}

///|
/// 在异步测试体完成时自动检查。异步任务应在作用域内汇合。
pub async fn[T] with_mock_async(body : async (Controller) -> T) -> T {
  Controller::new().run_scope_async(body)
}

///|
/// 启用有界调用历史，并在异步测试体完成后自动核对并关闭作用域。
/// 作用域取消时保留已选中的调用，待作用域完成清理后可查询历史。
pub async fn[T] with_mock_history_async(
  capacity : Int32,
  body : async (Controller) -> T,
) -> T {
  history_scope_controller(capacity).run_scope_async(body)
}

///|
async fn[T] Controller::run_scope_async(
  self : Controller,
  body : async (Controller) -> T,
) -> T {
  defer {
    self.closed = true
  }
  let result = body(self)
  self.verify()
  result
}

///|
pub struct Sequence {
  priv tickets : Array[Ticket]
  priv mut cursor : Int32
  priv mut owner : Controller?
}

///|
/// 组内预期按登记顺序匹配。独立顺序组可以交错执行。
pub fn Sequence::new() -> Sequence {
  { tickets: [], cursor: 0, owner: None, }
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
