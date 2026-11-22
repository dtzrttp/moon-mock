///|
test "选择末尾预期（1、32、256 条）" (b : @bench.T) {
  for size in [1, 32, 256] {
    let controller = @runtime.Controller::new()
    let slot : @runtime.Method[Int32, Int32] = @runtime.Method::new(
      controller, "Cache.get",
    )
    for value in 0..<size {
      slot.expect(
        @runtime.equal_to(value),
        value,
        count=@runtime.CallCount::at_least(0),
      )
    }
    b.bench(name="末尾匹配/" + size.to_string(), () => {
      b.keep(slot.try_take(size - 1))
    })
  }
}

///|
test "成功匹配首个预期和参数不符" (b : @bench.T) {
  let controller = @runtime.Controller::new()
  let slot : @runtime.Method[String, Int32] = @runtime.Method::new(
    controller, "Transport.status",
  )
  slot.expect(
    @runtime.equal_to("/health"),
    200,
    count=@runtime.CallCount::at_least(0),
  )
  b.bench(name="首项成功", () => b.keep(slot.try_take("/health")))
  b.bench(name="失败诊断", () => b.keep(slot.try_take("/missing")))
}

///|
test "创建并完成32步有序调用" (b : @bench.T) {
  b.bench(() => {
    let controller = @runtime.Controller::new()
    let sequence = @runtime.Sequence::new()
    let slot : @runtime.Method[Int32, Int32] = @runtime.Method::new(
      controller, "Task.step",
    )
    for i in 0..<32 {
      slot.expect(@runtime.equal_to(i), i, sequence~)
    }
    for i in 0..<32 {
      b.keep(slot.try_take(i))
    }
    b.keep(controller.missing_calls())
  })
}
