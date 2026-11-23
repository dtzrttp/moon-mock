///|
test "订单成功时按预留、扣款、持久化顺序执行" {
  @mock_runtime.with_mock_history(16, c => {
    let inventory = MockInventory::new(c)
    let payment = MockPayments::new(c)
    let orders = MockOrders::new(c)
    let sequence = @mock_runtime.Sequence::new()
    inventory.expect_reserve(
      @mock_runtime.equal_to(("book", 2)),
      "reserve-1",
      sequence~,
    )
    payment.expect_charge(
      @mock_runtime.equal_to(("request-1", 60)),
      "receipt-1",
      sequence~,
    )
    let saved = @mock_runtime.Capture::new()
    orders.expect_save(saved.matcher(@mock_runtime.any()), (), sequence~)
    inventory.expect_release(@mock_runtime.any(), (), times=0)
    payment.expect_refund(@mock_runtime.any(), (), times=0)
    let result = checkout(inventory, payment, orders, valid_order())
    guard result is Ok(order) else { fail("成功订单应返回结果") }
    assert_eq(order.amount, 60)
    assert_eq(order.receipt, "receipt-1")
    assert_eq(order.reservation, "reserve-1")
    assert_eq(saved.values(), [order])
    let history = c.history()
    assert_eq(history.length(), 3)
    assert_eq(history[0].method_name, "Inventory.reserve")
    assert_eq(history[1].method_name, "Payments.charge")
    assert_eq(history[2].method_name, "Orders.save")
  })
}

///|
test "库存不足不发生扣款和补偿" {
  @mock_runtime.with_mock(c => {
    let inventory = MockInventory::new(c)
    let payment = MockPayments::new(c)
    let orders = MockOrders::new(c)
    inventory.raise_reserve(@mock_runtime.any(), NoStock)
    payment.expect_charge(@mock_runtime.any(), "unused", times=0)
    orders.expect_save(@mock_runtime.any(), (), times=0)
    inventory.expect_release(@mock_runtime.any(), (), times=0)
    guard checkout(inventory, payment, orders, valid_order()) is Err(failure) else {
      fail("库存不足应失败")
    }
    assert_eq(failure.phase, "reserve")
    assert_true(failure.cause is NoStock)
    assert_eq(failure.cleanup_errors.length(), 0)
  })
}

///|
test "扣款失败只释放已预留库存" {
  @mock_runtime.with_mock(c => {
    let inventory = MockInventory::new(c)
    let payment = MockPayments::new(c)
    let orders = MockOrders::new(c)
    let sequence = @mock_runtime.Sequence::new()
    inventory.expect_reserve(@mock_runtime.any(), "reserved", sequence~)
    payment.raise_charge(@mock_runtime.any(), ChargeDeclined, sequence~)
    inventory.expect_release(@mock_runtime.equal_to("reserved"), (), sequence~)
    orders.expect_save(@mock_runtime.any(), (), times=0)
    payment.expect_refund(@mock_runtime.any(), (), times=0)
    guard checkout(inventory, payment, orders, valid_order()) is Err(failure) else {
      fail("扣款失败应返回错误")
    }
    assert_eq(failure.phase, "charge")
    assert_true(failure.cause is ChargeDeclined)
    assert_eq(failure.cleanup_errors.length(), 0)
  })
}

///|
test "保存失败先退款再释放库存，两步失败均保留" {
  @mock_runtime.with_mock_history(16, c => {
    let inventory = MockInventory::new(c)
    let payment = MockPayments::new(c)
    let orders = MockOrders::new(c)
    let sequence = @mock_runtime.Sequence::new()
    inventory.expect_reserve(@mock_runtime.any(), "reserved", sequence~)
    payment.expect_charge(@mock_runtime.any(), "charged", sequence~)
    orders.raise_save(@mock_runtime.any(), StoreUnavailable, sequence~)
    payment.raise_refund(
      @mock_runtime.equal_to("charged"),
      CleanupUnavailable,
      sequence~,
    )
    inventory.raise_release(
      @mock_runtime.equal_to("reserved"),
      CleanupUnavailable,
      sequence~,
    )
    guard checkout(inventory, payment, orders, valid_order()) is Err(failure) else {
      fail("持久化失败应返回补偿结果")
    }
    assert_eq(failure.phase, "save")
    assert_true(failure.cause is StoreUnavailable)
    assert_eq(failure.cleanup_errors.length(), 2)
    assert_eq(failure.cleanup_errors[0].0, "refund")
    assert_eq(failure.cleanup_errors[1].0, "release")
    assert_true(failure.cleanup_errors[0].1 is CleanupUnavailable)
    assert_true(failure.cleanup_errors[1].1 is CleanupUnavailable)
    assert_eq(c.history().length(), 5)
  })
}

///|
test "扣款失败时释放异常不覆盖主错误" {
  @mock_runtime.with_mock(c => {
    let inventory = MockInventory::new(c)
    let payment = MockPayments::new(c)
    let orders = MockOrders::new(c)
    inventory.expect_reserve(@mock_runtime.any(), "reserved")
    payment.raise_charge(@mock_runtime.any(), ChargeDeclined)
    inventory.raise_release(@mock_runtime.any(), CleanupUnavailable)
    guard checkout(inventory, payment, orders, valid_order()) is Err(failure) else {
      fail("应失败")
    }
    assert_true(failure.cause is ChargeDeclined)
    assert_eq(failure.cleanup_errors.length(), 1)
    assert_eq(failure.cleanup_errors[0].0, "release")
  })
}
