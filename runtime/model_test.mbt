///|
priv struct ReferenceRandom {
  mut state : Int32
}

///|
fn ReferenceRandom::next(self : ReferenceRandom, bound : Int32) -> Int32 {
  self.state = (self.state * 25173 + 13849) % 65536
  self.state % bound
}

///|
test "固定64个种子对照独立次数模型，共19200次调用" {
  for seed in 1..<=64 {
    let random = { state: seed, }
    let controller = @runtime.Controller::new()
    let slot : @runtime.Method[Int32, Int32] = @runtime.Method::new(
      controller, "model",
    )
    let keys = []
    let minima = []
    let maxima = []
    let seen = []
    for i in 0..<24 {
      let key = random.next(12)
      let minimum = random.next(3)
      let maximum = minimum + random.next(5)
      keys.push(key)
      minima.push(minimum)
      maxima.push(maximum)
      seen.push(0)
      slot.expect(
        @runtime.equal_to(key),
        i,
        count=@runtime.CallCount::between(minimum, maximum),
      )
    }
    for _ in 0..<300 {
      let key = random.next(16)
      let mut selected : Int32? = None
      let mut has_matching = false
      for i in 0..<keys.length() {
        if keys[i] == key {
          has_matching = true
          if selected is None && seen[i] < maxima[i] {
            selected = Some(i)
          }
        }
      }
      let actual = slot.try_take(key)
      match selected {
        Some(i) => {
          assert_true(actual is Ok(value) && value == i)
          seen[i] += 1
        }
        None => {
          guard actual is Err(failure) else {
            fail("参考模型拒绝了调用")
          }
          let code = if has_matching {
            "too_many_calls"
          } else {
            "argument_mismatch"
          }
          assert_eq(failure.code, code)
        }
      }
    }
    let statuses = controller.snapshot()
    for i in 0..<seen.length() {
      assert_eq(statuses[i].seen, seen[i])
      assert_eq(statuses[i].minimum, minima[i])
      assert_eq(statuses[i].maximum, Some(maxima[i]))
      assert_eq(statuses[i].satisfied, seen[i] >= minima[i])
    }
    let mut missing = 0
    for i in 0..<minima.length() {
      if seen[i] < minima[i] {
        missing += 1
      }
    }
    assert_eq(controller.missing_calls().length(), missing)
  }
}

///|
test "固定32个种子对照有序区间模型，共12800次调用" {
  for seed in 1..<=32 {
    let random = { state: seed + 200, }
    let controller = @runtime.Controller::new()
    let sequence = @runtime.Sequence::new()
    let slot : @runtime.Method[Int32, Int32] = @runtime.Method::new(
      controller, "sequence",
    )
    let minima = []
    let maxima = []
    let seen = []
    let mut cursor = 0
    for i in 0..<16 {
      let minimum = random.next(3)
      let maximum = minimum + 1 + random.next(3)
      minima.push(minimum)
      maxima.push(maximum)
      seen.push(0)
      slot.expect(
        @runtime.equal_to(i),
        i,
        count=@runtime.CallCount::between(minimum, maximum),
        sequence~,
      )
    }
    for turn in 0..<400 {
      // 混合顺序前进、重复当前步骤和跳跃，使上下限都被触及。
      let index = if turn % 3 == 0 { cursor } else { random.next(16) }
      let exhausted = seen[index] >= maxima[index]
      let mut blocked = index < cursor
      if index >= cursor {
        for i in cursor..<index {
          blocked = blocked || seen[i] < minima[i]
        }
      }
      let actual = slot.try_take(index)
      if exhausted {
        assert_true(actual is Err(failure) && failure.code == "too_many_calls")
      } else if blocked {
        assert_true(actual is Err(failure) && failure.code == "out_of_order")
      } else {
        assert_true(actual is Ok(value) && value == index)
        seen[index] += 1
        cursor = index
      }
    }
    let statuses = controller.snapshot()
    for i in 0..<seen.length() {
      assert_eq(statuses[i].seen, seen[i])
    }
  }
}
