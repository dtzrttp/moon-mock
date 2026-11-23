///|
/// 完全离线的业务示例。金额为整数最小货币单位；不实现真实支付或幂等存储。
pub suberror CheckoutError {
  InvalidRequest(String)
  NoStock
  ChargeDeclined
  StoreUnavailable
  CleanupUnavailable
  NotificationUnavailable
} derive(Debug)

///|
pub extend CheckoutError with Debug::{to_repr}

///|
pub(all) struct OrderRequest {
  key : String
  sku : String
  quantity : Int32
  unit_price : Int32
}

///|
pub(all) struct PlacedOrder {
  key : String
  sku : String
  quantity : Int32
  amount : Int32
  reservation : String
  receipt : String
} derive(Eq, Debug)

///|
pub extend PlacedOrder with Eq::{equal, not_equal}

///|
pub extend PlacedOrder with Debug::{to_repr}

///|
/// 补偿失败与业务主错误分别保留，不静默吞掉任何一次清理失败。
pub(all) struct CheckoutFailure {
  phase : String
  cause : CheckoutError
  cleanup_errors : Array[(String, CheckoutError)]
}

///|
pub(open) trait Inventory {
  fn reserve(Self, String, Int32) -> String raise CheckoutError
  fn release(Self, String) -> Unit raise CheckoutError
}

///|
pub(open) trait Payments {
  fn charge(Self, String, Int32) -> String raise CheckoutError
  fn refund(Self, String) -> Unit raise CheckoutError
}

///|
pub(open) trait Orders {
  fn save(Self, PlacedOrder) -> Unit raise CheckoutError
}

///|
pub(open) trait Notifications {
  async fn publish(Self, PlacedOrder) -> Unit raise CheckoutError
}

///|
fn validate_order(request : OrderRequest) -> Int32 raise CheckoutError {
  if request.key.trim().is_empty() {
    raise InvalidRequest(
      "必须提供幂等键；实际幂等处理由支付接口负责",
    )
  }
  if request.sku.trim().is_empty() {
    raise InvalidRequest("SKU不能为空")
  }
  if request.quantity <= 0 || request.quantity > 1000 {
    raise InvalidRequest("数量必须在1到1000之间")
  }
  if request.unit_price <= 0 {
    raise InvalidRequest("单价必须为正数")
  }
  if request.unit_price > 2147483647 / request.quantity {
    raise InvalidRequest("订单总金额超过Int32范围")
  }
  request.unit_price * request.quantity
}

///|
fn[I : Inventory] release_reservation(
  inventory : I,
  reservation : String,
  errors : Array[(String, CheckoutError)],
) -> Unit {
  Inventory::release(inventory, reservation) catch {
    error => errors.push(("release", error))
  }
}

///|
/// 预留库存后扣款，再保存订单。保存失败时依次退款和释放库存。
pub fn[I : Inventory, P : Payments, O : Orders] checkout(
  inventory : I,
  payment : P,
  orders : O,
  request : OrderRequest,
) -> Result[PlacedOrder, CheckoutFailure] {
  let amount = validate_order(request) catch {
    error =>
      return Err({ phase: "validate", cause: error, cleanup_errors: [], })
  }
  let reservation = Inventory::reserve(inventory, request.sku, request.quantity) catch {
    error => return Err({ phase: "reserve", cause: error, cleanup_errors: [], })
  }
  let receipt = Payments::charge(payment, request.key, amount) catch {
    error => {
      let cleanup_errors = []
      release_reservation(inventory, reservation, cleanup_errors)
      return Err({ phase: "charge", cause: error, cleanup_errors, })
    }
  }
  let order = {
    key: request.key,
    sku: request.sku,
    quantity: request.quantity,
    amount,
    reservation,
    receipt,
  }
  Orders::save(orders, order) catch {
    error => {
      let cleanup_errors = []
      Payments::refund(payment, receipt) catch {
        cleanup => cleanup_errors.push(("refund", cleanup))
      }
      release_reservation(inventory, reservation, cleanup_errors)
      return Err({ phase: "save", cause: error, cleanup_errors, })
    }
  }
  Ok(order)
}

///|
pub(all) struct DeliveryResult {
  order : PlacedOrder
  notification_pending : Bool
}

///|
/// 保存成功后通知失败仅标记待重试，不撤销已经持久化的订单。
/// 这是调用编排示例，不提供消息持久化或后台重试队列。
pub async fn[I : Inventory, P : Payments, O : Orders, N : Notifications] submit_order(
  inventory : I,
  payment : P,
  orders : O,
  notifications : N,
  request : OrderRequest,
) -> Result[DeliveryResult, CheckoutFailure] {
  match checkout(inventory, payment, orders, request) {
    Err(failure) => Err(failure)
    Ok(order) => {
      let delivered = Ok(Notifications::publish(notifications, order)) catch {
        _ => Err(())
      }
      let pending = delivered is Err(_)
      Ok({ order, notification_pending: pending, })
    }
  }
}
