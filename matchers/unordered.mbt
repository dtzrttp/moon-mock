///|
let unordered_limit : Int32 = 128

///|
// 沿前驱链把路径上的现有配对逐个挪到新位置。
fn assign_path(
  free_position : Int32,
  predecessor : Array[Int32],
  owner : Array[Int32],
  assigned : Array[Int32],
) -> Unit {
  let mut position = free_position
  while position >= 0 {
    let child = predecessor[position]
    let previous = assigned[child]
    owner[position] = child
    assigned[child] = position
    position = previous
  }
}

///|
// 每个实际位置至多访问一次，位置的当前拥有者可继续寻找替代位置。
fn[A] augment_assignment(
  root : Int32,
  children : Array[@runtime.Matcher[A]],
  actual : Array[A],
  owner : Array[Int32],
  assigned : Array[Int32],
) -> Bool {
  let predecessor = Array::make(actual.length(), -1)
  let pending = [root]
  for next = 0; next < pending.length(); next = next + 1 {
    let child_index = pending[next]
    let child = children[child_index]
    for position in 0..<actual.length() {
      if predecessor[position] >= 0 || !child.matches(actual[position]) {
        continue
      }
      predecessor[position] = child_index
      if owner[position] < 0 {
        assign_path(position, predecessor, owner, assigned)
        return true
      }
      pending.push(owner[position])
    }
  }
  false
}

///|
fn[A] unordered_assignment(
  children : Array[@runtime.Matcher[A]],
  actual : Array[A],
) -> Array[Int32]? {
  let length = children.length()
  if actual.length() != length {
    return None
  }
  let owner = Array::make(length, -1)
  let assigned = Array::make(length, -1)
  for root in 0..<length {
    if !augment_assignment(root, children, actual, owner, assigned) {
      return None
    }
  }
  Some(assigned)
}

///|
/// 检查数组和子匹配器之间是否存在一一对应关系。重复元素各占一个位置。
/// 构造时复制子匹配器，至多接受 128 项，超限返回 `too_many_elements`。
/// 搜索依两侧的索引顺序进行；调用被选中时按子匹配器顺序转发最终配对的值。
/// 子谓词可能运行多次，应保持无副作用。最坏执行时间为立方量级，额外空间为线性量级。
pub fn[A] unordered_elements(
  expected : Array[@runtime.Matcher[A]],
) -> Result[@runtime.Matcher[Array[A]], @runtime.CallFailure] {
  if expected.length() > unordered_limit {
    return Err(
      @runtime.CallFailure::new(
        "too_many_elements",
        "无序匹配最多接受 \{unordered_limit} 项，收到 \{expected.length()} 项",
      ),
    )
  }
  let children = expected.copy()
  Ok(
    @runtime.Matcher::compose(
      "无序且逐项匹配 \{describe_elements(children)}",
      actual => unordered_assignment(children, actual) is Some(_),
      Some(describe_array),
      (actual, selection) => {
        if unordered_assignment(children, actual) is Some(assigned) {
          let selected = actual.copy()
          for index in 0..<children.length() {
            children[index].prepare_selected(
              selected[assigned[index]],
              selection,
            )
          }
        }
      },
    ),
  )
}
