///|
priv struct ExpectedHistoryEvent {
  ordinal : Int64
  method_name : String
  result : Result[Int32, String]
}

///|
/// 参考模型保留自上次清理以来的整个流，读取时才截取尾部。
/// 选择规则使用显式分支，与实际运行时的循环和顺序状态无关。
priv struct ReferenceHistory {
  capacity : Int32
  events : Array[ExpectedHistoryEvent]
  mut ordinal : Int64
  mut primary_seen : Int32
  mut fallback_seen : Int32
  mut secondary_seen : Int32
}

///|
fn ReferenceHistory::push(
  self : ReferenceHistory,
  slot_index : Int32,
  value : Int32,
) -> Result[Int32, String] {
  let (method_name, result) = match (slot_index, value) {
    (0, 1) if self.primary_seen < 2 => {
      self.primary_seen += 1
      ("primary", Ok(0))
    }
    (0, 1) => {
      self.fallback_seen += 1
      ("primary", Ok(2))
    }
    (0, _) => ("primary", Err("argument_mismatch"))
    (1, 3) if self.secondary_seen == 0 => {
      self.secondary_seen += 1
      ("secondary", Ok(1))
    }
    (1, 3) => ("secondary", Err("too_many_calls"))
    (1, _) => ("secondary", Err("argument_mismatch"))
    _ => ("empty", Err("unexpected_call"))
  }
  self.ordinal += 1L
  self.events.push({ ordinal: self.ordinal, method_name, result, })
  result
}

///|
fn ReferenceHistory::assert_matches(
  self : ReferenceHistory,
  controller : @runtime.Controller,
) -> Unit raise {
  let actual = controller.history()
  let count = self.events.length()
  let dropped = if count > self.capacity { count - self.capacity } else { 0 }
  assert_eq(actual.length(), count - dropped)
  assert_eq(controller.history_dropped(), dropped.to_int64())
  for offset, observed in actual {
    let expected = self.events[dropped + offset]
    assert_eq(observed.ordinal, expected.ordinal)
    assert_eq(observed.method_name, expected.method_name)
    match expected.result {
      Ok(index) => {
        assert_eq(observed.outcome, "selected")
        assert_eq(observed.expectation_index, Some(index))
        assert_true(observed.failure_code is None)
      }
      Err(code) => {
        assert_eq(observed.outcome, "rejected")
        assert_true(observed.expectation_index is None)
        assert_eq(observed.failure_code, Some(code))
      }
    }
  }
}

///|
test "固定种子对照完整事件流验证回卷、清理及报告顺序" {
  for seed in 1..<=32 {
    let random : ReferenceRandom = { state: 1259 + seed * 23, }
    let capacity = 1 + seed % 11
    let reference : ReferenceHistory = {
      capacity,
      events: [],
      ordinal: 0L,
      primary_seen: 0,
      fallback_seen: 0,
      secondary_seen: 0,
    }
    let controller = history_controller(capacity)
    let primary : @runtime.Method[Int32, Int32] = @runtime.Method::new(
      controller, "primary",
    )
    let secondary : @runtime.Method[Int32, Int32] = @runtime.Method::new(
      controller, "secondary",
    )
    let empty : @runtime.Method[Int32, Int32] = @runtime.Method::new(
      controller, "empty",
    )
    // 穿插登记，确保事件索引来自控制器登记顺序，而非方法内部顺序。
    primary.expect(@runtime.equal_to(1), 0, times=2)
    secondary.expect(@runtime.equal_to(3), 1)
    primary.expect(
      @runtime.equal_to(1),
      2,
      count=@runtime.CallCount::at_least(0),
    )
    let slots = [primary, secondary, empty]
    for _ in 0..<240 {
      let opcode = random.next(19)
      if opcode == 0 {
        reference.events.clear()
        controller.clear_history()
      } else {
        let slot_index = opcode % slots.length()
        let value = random.next(5)
        let expected = reference.push(slot_index, value)
        let actual = slots[slot_index]
          .try_take(value)
          .map_err(failure => failure.code)
        assert_eq(actual, expected)
      }
      reference.assert_matches(controller)
    }
    assert_eq(controller.snapshot().map(status => status.seen), [
      reference.primary_seen,
      reference.secondary_seen,
      reference.fallback_seen,
    ])
  }
}
