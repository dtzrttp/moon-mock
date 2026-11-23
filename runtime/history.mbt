///|
/// 一次方法预期选择的不可变记录。
/// `ordinal` 以控制器为单位从 1 开始，在 Int64 上界饱和。
/// `outcome` 为 `selected` 或 `rejected`。拒绝使用调用错误码，选中时
/// `expectation_index` 指向控制器 `snapshot()` 中从 0 开始的登记位置。
pub struct CallEvent {
  ordinal : Int64
  method_name : String
  outcome : String
  failure_code : String?
  expectation_index : Int32?
} derive(Debug)

///|
pub extend CallEvent with Debug::{to_repr}

///|
/// Int64 序号以十进制字符串表示，缺失的错误码和预期索引使用 null。
pub impl ToJson for CallEvent with fn to_json(self : CallEvent) -> Json {
  {
    "ordinal": self.ordinal.to_string(),
    "method_name": self.method_name,
    "outcome": self.outcome,
    "failure_code": match self.failure_code {
      Some(code) => Json::string(code)
      None => null
    },
    "expectation_index": match self.expectation_index {
      Some(index) => Json(index)
      None => null
    },
  }
}

///|
pub extend CallEvent with ToJson::{to_json}

///|
/// 固定容量的循环缓冲区。未满时按进入顺序追加，满时 `head` 指向最旧记录。
priv struct CallHistory {
  capacity : Int32
  entries : Array[CallEvent]
  mut head : Int32
  mut last_ordinal : Int64
  mut dropped : Int64
}

///|
const MAX_HISTORY_CAPACITY : Int32 = 65536

///|
const MAX_HISTORY_COUNTER : Int64 = 9223372036854775807L

///|
/// 创建保存最近 `capacity` 次调用的控制器。有效范围为 1 至 65536。
/// 容量之外的值返回 `invalid_history_capacity`。
pub fn Controller::with_history(
  capacity : Int32,
) -> Result[Controller, CallFailure] {
  if capacity < 1 || capacity > MAX_HISTORY_CAPACITY {
    return Err({
      code: "invalid_history_capacity",
      message: "历史容量 \{capacity} 超出有效范围 1 至 \{MAX_HISTORY_CAPACITY}",
    })
  }
  let history : CallHistory = {
    capacity,
    entries: [],
    head: 0,
    last_ordinal: 0L,
    dropped: 0L,
  }
  Ok({ tickets: [], closed: false, history_buffer: Some(history), })
}

///|
/// 自动核对作用域收到无效历史容量。
pub suberror HistoryConfigError {
  InvalidHistoryCapacity(String)
} derive(Debug)

///|
pub extend HistoryConfigError with Debug::{to_repr}

///|
fn history_scope_controller(
  capacity : Int32,
) -> Controller raise HistoryConfigError {
  match Controller::with_history(capacity) {
    Ok(controller) => controller
    Err(failure) => raise InvalidHistoryCapacity(failure.message)
  }
}

///|
fn CallHistory::record(
  self : CallHistory,
  method_name : String,
  outcome : String,
  failure_code : String?,
  expectation_index : Int32?,
) -> Unit {
  if self.last_ordinal < MAX_HISTORY_COUNTER {
    self.last_ordinal += 1L
  }
  let event = {
    ordinal: self.last_ordinal,
    method_name,
    outcome,
    failure_code,
    expectation_index,
  }
  if self.entries.length() < self.capacity {
    self.entries.push(event)
  } else {
    self.entries[self.head] = event
    self.head = (self.head + 1) % self.capacity
    if self.dropped < MAX_HISTORY_COUNTER {
      self.dropped += 1L
    }
  }
}

///|
/// 按预期选择顺序返回当前保留记录的独立副本。默认关闭时返回空数组。
/// 记录只保存选择结果及方法名，包括作用域关闭后的调用拒绝。
/// 调用参数、行为回调结果、诊断消息以及匹配器说明均不进入历史。
pub fn Controller::history(self : Controller) -> Array[CallEvent] {
  guard self.history_buffer is Some(history) else { return [] }
  if history.head == 0 {
    return history.entries.copy()
  }
  Array::makei(history.entries.length(), offset => {
    history.entries[(history.head + offset) % history.capacity]
  })
}

///|
/// 清除当前记录并将丢弃数归零，保留已使用的序号和预期计数。
pub fn Controller::clear_history(self : Controller) -> Unit {
  if self.history_buffer is Some(history) {
    history.entries.clear()
    history.head = 0
    history.dropped = 0L
  }
}

///|
/// 返回因容量不足丢弃的历史条数，以最近一次清理为起点，在 Int64 上界饱和。
pub fn Controller::history_dropped(self : Controller) -> Int64 {
  match self.history_buffer {
    Some(history) => history.dropped
    None => 0L
  }
}

///|
/// 生成版本 1 的独立历史报告。关闭记录时容量为 0。
/// `dropped` 与事件中的 `ordinal` 使用十进制字符串保留完整精度。
pub fn Controller::history_report(self : Controller) -> Json {
  let capacity = match self.history_buffer {
    Some(history) => history.capacity
    None => 0
  }
  {
    "schema_version": 1,
    "enabled": capacity > 0,
    "capacity": capacity,
    "dropped": self.history_dropped().to_string(),
    "events": Json(self.history()),
  }
}
