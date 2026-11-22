///|
/// 一条预期的不可变计数快照。顺序与预期登记顺序一致。
pub struct ExpectationStatus {
  method_name : String
  matcher : String
  minimum : Int32
  maximum : Int32?
  seen : Int32
  satisfied : Bool
} derive(Debug, ToJson)

///|
pub extend ExpectationStatus with Debug::{to_repr}

///|
pub extend ExpectationStatus with ToJson::{to_json}

///|
pub fn Controller::snapshot(self : Controller) -> Array[ExpectationStatus] {
  self.tickets.map(ticket => {
    method_name: ticket.name,
    matcher: ticket.description,
    minimum: ticket.count.minimum,
    maximum: ticket.count.maximum,
    seen: ticket.seen,
    satisfied: ticket.seen >= ticket.count.minimum,
  })
}

///|
/// JSON 报告包含计数与匹配说明，说明中可能带有使用者提供的测试数据。
pub fn Controller::report(self : Controller) -> Json {
  {
    "schema_version": 1,
    "closed": self.closed,
    "expectations": Json(self.snapshot()),
  }
}
