///|
fn valid_order() -> OrderRequest {
  { key: "request-1", sku: "book", quantity: 2, unit_price: 30, }
}

///|
test "所有无效请求均在外部调用前失败" {
  for
    request in [
      { key: "", sku: "book", quantity: 1, unit_price: 30, },
      { key: " ", sku: "book", quantity: 1, unit_price: 30, },
      { key: "a", sku: "", quantity: 1, unit_price: 30, },
      { key: "a", sku: " \n", quantity: 1, unit_price: 30, },
      { key: "a", sku: "book", quantity: 0, unit_price: 30, },
      { key: "a", sku: "book", quantity: -1, unit_price: 30, },
      { key: "a", sku: "book", quantity: 1001, unit_price: 30, },
      { key: "a", sku: "book", quantity: 1, unit_price: 0, },
      { key: "a", sku: "book", quantity: 1, unit_price: -1, },
      { key: "a", sku: "book", quantity: 2, unit_price: 2147483647, },
    ] {
    @mock_runtime.with_mock_history(8, c => {
      let result = checkout(
        MockInventory::new(c),
        MockPayments::new(c),
        MockOrders::new(c),
        request,
      )
      guard result is Err(failure) else { fail("不应调用任何依赖") }
      assert_eq(failure.phase, "validate")
      assert_true(failure.cause is InvalidRequest(_))
      assert_eq(failure.cleanup_errors.length(), 0)
      assert_eq(c.history().length(), 0)
    })
  }
}

///|
test "金额上界和数量上界不溢出且不擅自舍入" {
  assert_eq(
    validate_order({ key: "a", sku: "s", quantity: 1, unit_price: 2147483647, }),
    2147483647,
  )
  assert_eq(
    validate_order({ key: "a", sku: "s", quantity: 1000, unit_price: 2147483, }),
    2147483000,
  )
  assert_eq(
    validate_order({ key: "a", sku: "s", quantity: 3, unit_price: 7, }),
    21,
  )
}

///|
test "中文SKU和外部幂等键原样传入依赖" {
  @mock_runtime.with_mock(c => {
    let inventory = MockInventory::new(c)
    let payment = MockPayments::new(c)
    let orders = MockOrders::new(c)
    inventory.expect_reserve(
      @mock_runtime.equal_to(("电子书🚲", 1)),
      "预留",
    )
    payment.expect_charge(
      @mock_runtime.equal_to(("请求编号一", 19)),
      "凭证",
    )
    orders.expect_save(@mock_runtime.any(), ())
    let result = checkout(inventory, payment, orders, {
      key: "请求编号一",
      sku: "电子书🚲",
      quantity: 1,
      unit_price: 19,
    })
    guard result is Ok(order) else { fail("应成功") }
    assert_eq(order.sku, "电子书🚲")
    assert_eq(order.key, "请求编号一")
  })
}

///|
test "补偿成功保留主错误并清空清理错误" {
  @mock_runtime.with_mock(c => {
    let inventory = MockInventory::new(c)
    let payment = MockPayments::new(c)
    let orders = MockOrders::new(c)
    let sequence = @mock_runtime.Sequence::new()
    inventory.expect_reserve(@mock_runtime.any(), "r", sequence~)
    payment.expect_charge(@mock_runtime.any(), "p", sequence~)
    orders.raise_save(@mock_runtime.any(), StoreUnavailable, sequence~)
    payment.expect_refund(@mock_runtime.equal_to("p"), (), sequence~)
    inventory.expect_release(@mock_runtime.equal_to("r"), (), sequence~)
    guard checkout(inventory, payment, orders, valid_order()) is Err(failure) else {
      fail("应失败")
    }
    assert_true(failure.cause is StoreUnavailable)
    assert_eq(failure.cleanup_errors.length(), 0)
  })
}

///|
test "只有退款失败时仍然执行库存释放" {
  @mock_runtime.with_mock(c => {
    let inventory = MockInventory::new(c)
    let payment = MockPayments::new(c)
    let orders = MockOrders::new(c)
    inventory.expect_reserve(@mock_runtime.any(), "r")
    payment.expect_charge(@mock_runtime.any(), "p")
    orders.raise_save(@mock_runtime.any(), StoreUnavailable)
    payment.raise_refund(@mock_runtime.any(), CleanupUnavailable)
    inventory.expect_release(@mock_runtime.any(), ())
    guard checkout(inventory, payment, orders, valid_order()) is Err(failure) else {
      fail("应失败")
    }
    assert_eq(failure.cleanup_errors.length(), 1)
    assert_eq(failure.cleanup_errors[0].0, "refund")
  })
}
