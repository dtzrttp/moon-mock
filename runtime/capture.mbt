///|
/// 记录成功匹配的调用参数。集合副本中的引用类型保持 MoonBit 的引用语义。
pub struct Capture[A] {
  priv captured : Array[A]
}

///|
pub fn[A] Capture::new() -> Capture[A] {
  { captured: [], }
}

///|
/// 次数和顺序检查通过后，在行为回调执行前记录参数。
pub fn[A] Capture::matcher(self : Capture[A], inner : Matcher[A]) -> Matcher[A] {
  {
    ..inner,
    on_selected: Some(value => {
      inner.selected(value)
      self.captured.push(value)
    }),
  }
}

///|
/// 按调用进入顺序返回数组副本。
pub fn[A] Capture::values(self : Capture[A]) -> Array[A] {
  self.captured.copy()
}
