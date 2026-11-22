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
/// JSON 报告只包含计数及匹配说明。仅传递给 equal_to 的值会出现在说明中。
pub fn Controller::report(self : Controller) -> Json {
  {
    "schema_version": 1,
    "closed": self.closed,
    "expectations": Json(self.snapshot()),
  }
}
