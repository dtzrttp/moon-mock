///|
fn successful_dependencies(
  c : @mock_runtime.Controller,
) -> (MockInventory, MockPayments, MockOrders) {
  let inventory = MockInventory::new(c)
  let payment = MockPayments::new(c)
  let orders = MockOrders::new(c)
  inventory.expect_reserve(
    @matchers.pair(@matchers.starts_with("bo"), @matchers.greater_than(0)),
    "reservation",
  )
  payment.expect_charge(@mock_runtime.any(), "receipt")
  orders.expect_save(@mock_runtime.any(), ())
  inventory.expect_release(@mock_runtime.any(), (), times=0)
  payment.expect_refund(@mock_runtime.any(), (), times=0)
  (inventory, payment, orders)
}

///|
async test "通知挂起后成功或失败都不撤销已保存订单" {
  for fail_notify in [false, true] {
    @mock_runtime.with_mock_history_async(16, async fn(c) {
      let (inventory, payment, orders) = successful_dependencies(c)
      let notifications = MockNotifications::new(c)
      let captured = @mock_runtime.Capture::new()
      notifications.respond_publish(captured.matcher(@mock_runtime.any()), async fn(
        _order,
      ) -> Unit raise CheckoutError {
        @async.pause()
        if fail_notify {
          raise NotificationUnavailable
        }
      })
      let result = submit_order(
        inventory,
        payment,
        orders,
        notifications,
        valid_order(),
      )
      guard result is Ok(delivery) else {
        fail("保存后的订单不能因通知失败被撤销")
      }
      assert_eq(delivery.notification_pending, fail_notify)
      assert_eq(captured.values(), [delivery.order])
      let history = c.history()
      assert_eq(history.length(), 4)
      assert_eq(history[3].method_name, "Notifications.publish")
      assert_eq(history[3].outcome, "selected")
      // 历史记录调用已被选择，不把用户回调之后的抛错误报成匹配失败。
      assert_eq(history[3].failure_code, None)
    })
  }
}

///|
async test "校验失败不尝试异步通知" {
  @mock_runtime.with_mock_history_async(8, async fn(c) {
    let inventory = MockInventory::new(c)
    let payment = MockPayments::new(c)
    let orders = MockOrders::new(c)
    let notifications = MockNotifications::new(c)
    notifications.expect_publish(@mock_runtime.any(), (), times=0)
    let request = { key: "", sku: "s", quantity: 1, unit_price: 30, }
    let result = submit_order(
      inventory, payment, orders, notifications, request,
    )
    guard result is Err(failure) else { fail("无效订单应失败") }
    assert_eq(failure.phase, "validate")
    assert_eq(c.history().length(), 0)
  })
}

///|
test "有界历史只保留最近调用且不保存客户参数" {
  @mock_runtime.with_mock_history(2, c => {
    let (inventory, payment, orders) = successful_dependencies(c)
    assert_true(checkout(inventory, payment, orders, valid_order()) is Ok(_))
    let events = c.history()
    assert_eq(events.length(), 2)
    assert_eq(events[0].method_name, "Payments.charge")
    assert_eq(events[1].method_name, "Orders.save")
    assert_eq(c.history_dropped(), 1L)
    let report = c.history_report().stringify()
    assert_false(report.contains("request-1"))
    assert_false(report.contains("book"))
    assert_false(report.contains("receipt"))
  })
}
