///|
test "逐位置匹配的完整成功和末项拒绝" (b : @bench.T) {
  for size in [8, 32, 128] {
    let children = Array::makei(size, index => @runtime.equal_to(index))
    let matcher = @matchers.exact_elements(children)
    let accepted = Array::makei(size, index => index)
    let rejected = accepted.copy()
    rejected[size - 1] = -1
    b.bench(name="全部匹配/" + size.to_string(), () => {
      b.keep(matcher.matches(accepted))
    })
    b.bench(name="末项拒绝/" + size.to_string(), () => {
      b.keep(matcher.matches(rejected))
    })
  }
}

///|
test "无序匹配的唯一位置和增广重排" (b : @bench.T) {
  for size in [8, 32, 128] {
    let actual = Array::makei(size, index => index)
    let unique = Array::makei(size, index => @runtime.equal_to(size - index - 1))
    let overlapping = Array::makei(size - 1, index => {
      @runtime.matching("相邻编号", value => {
        value == index || value == index + 1
      })
    })
    // 硬约束最后入队，必须沿前面已配对的链逐项改配。
    overlapping.push(@runtime.equal_to(0))
    guard @matchers.unordered_elements(unique) is Ok(reversed) else {
      abort("唯一位置基准构造失败")
    }
    guard @matchers.unordered_elements(overlapping) is Ok(reassigned) else {
      abort("增广重排基准构造失败")
    }
    b.bench(name="唯一位置/" + size.to_string(), () => {
      b.keep(reversed.matches(actual))
    })
    b.bench(name="增广重排/" + size.to_string(), () => {
      b.keep(reassigned.matches(actual))
    })
  }
}
