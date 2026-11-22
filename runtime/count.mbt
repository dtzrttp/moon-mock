///|
/// 调用次数约束。未指定上限时，达到下限后仍可继续匹配。
pub struct CallCount {
  priv minimum : Int32
  priv maximum : Int32?
}

///|
/// 精确次数。传入零表示禁止匹配调用。
pub fn CallCount::exact(times : Int32) -> CallCount {
  CallCount::between(times, times)
}

///|
/// 含上下限的区间。下限必须非负，且不能超过上限。
pub fn CallCount::between(minimum : Int32, maximum : Int32) -> CallCount {
  match CallCount::try_between(minimum, maximum) {
    Ok(count) => count
    Err(error) => abort(error.code + ": " + error.message)
  }
}

///|
/// 只设下限，例如测试允许额外的重试调用。
pub fn CallCount::at_least(minimum : Int32) -> CallCount {
  match CallCount::try_at_least(minimum) {
    Ok(count) => count
    Err(error) => abort(error.code + ": " + error.message)
  }
}

///|
pub fn CallCount::try_between(
  minimum : Int32,
  maximum : Int32,
) -> Result[CallCount, CallFailure] {
  if minimum < 0 || maximum < minimum {
    return Err({
      code: "invalid_count",
      message: "需要满足 0 <= 最少次数 <= 最多次数",
    })
  }
  Ok({ minimum, maximum: Some(maximum), })
}

///|
pub fn CallCount::try_at_least(
  minimum : Int32,
) -> Result[CallCount, CallFailure] {
  if minimum < 0 {
    return Err({
      code: "invalid_count",
      message: "最少次数不能为负数",
    })
  }
  Ok({ minimum, maximum: None, })
}

///|
fn CallCount::describe(self : CallCount) -> String {
  match self.maximum {
    Some(maximum) if maximum == self.minimum => "\{maximum} 次"
    Some(maximum) => "\{self.minimum}–\{maximum} 次"
    None => "至少 \{self.minimum} 次"
  }
}
