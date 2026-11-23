///|
test "有界历史满载时选中预期" (b : @bench.T) {
  // 循环缓冲区填满后再测量，避免首次扩容影响连续运行时的开销。
  for capacity in [0, 1, 64, 1024] {
    let controller = if capacity == 0 {
      @runtime.Controller::new()
    } else {
      match @runtime.Controller::with_history(capacity) {
        Ok(controller) => controller
        Err(failure) => abort(failure.message)
      }
    }
    let slot : @runtime.Method[Unit, Int32] = @runtime.Method::new(
      controller, "Booking.confirm",
    )
    slot.expect(@runtime.any(), 1, count=@runtime.CallCount::at_least(0))
    for _ in 0..<capacity {
      slot.take(()) |> ignore
    }
    b.bench(name="容量/" + capacity.to_string(), () => {
      b.keep(slot.try_take(()))
    })
  }
}

///|
test "已回卷历史的复制和 JSON 序列化" (b : @bench.T) {
  for capacity in [32, 1024] {
    guard @runtime.Controller::with_history(capacity) is Ok(controller) else {
      abort("基准使用的历史容量无效")
    }
    let slot : @runtime.Method[String, Unit] = @runtime.Method::new(
      controller, "Inventory.reserve",
    )
    slot.expect(
      @runtime.equal_to("accepted"),
      (),
      count=@runtime.CallCount::at_least(0),
    )
    for index in 0..<=capacity {
      if index % 2 == 0 {
        slot.take("accepted")
      } else {
        slot.try_take("rejected") |> ignore
      }
    }
    b.bench(name="快照/" + capacity.to_string(), () => {
      b.keep(controller.history())
    })
    b.bench(name="JSON/" + capacity.to_string(), () => {
      b.keep(controller.history_report().stringify())
    })
  }
}
