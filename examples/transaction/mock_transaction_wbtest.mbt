// 由 moon-mock 生成，请从原 trait 重新生成。

///|
struct MockTransaction {
  slot_begin : @mock_runtime.Method[Unit, (Unit) -> Unit]
  slot_insert : @mock_runtime.Method[
    (String, Int32),
    ((String, Int32)) -> Unit raise DatabaseError,
  ]
  slot_commit : @mock_runtime.Method[Unit, (Unit) -> Unit]
  slot_rollback : @mock_runtime.Method[Unit, (Unit) -> Unit]
}

///|
#warnings("-unused_value")
fn MockTransaction::new(c : @mock_runtime.Controller) -> MockTransaction {
  {
    slot_begin: @mock_runtime.Method::new(c, "Transaction.begin"),
    slot_insert: @mock_runtime.Method::new(c, "Transaction.insert"),
    slot_commit: @mock_runtime.Method::new(c, "Transaction.commit"),
    slot_rollback: @mock_runtime.Method::new(c, "Transaction.rollback"),
  }
}

///|
#warnings("-unused_value")
fn MockTransaction::expect_begin(
  self : MockTransaction,
  matcher : @mock_runtime.Matcher[Unit],
  value : Unit,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
) -> Unit {
  self.slot_begin.expect(matcher, _ => value, times~, sequence?)
}

///|
#warnings("-unused_value")
fn MockTransaction::respond_begin(
  self : MockTransaction,
  matcher : @mock_runtime.Matcher[Unit],
  action : (Unit) -> Unit,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
) -> Unit {
  self.slot_begin.expect(matcher, action, times~, sequence?)
}

///|
impl Transaction for MockTransaction with fn begin(self) {
  let args = ()
  let action = self.slot_begin.take(args)
  action(args)
}

///|
#warnings("-unused_value")
fn MockTransaction::expect_insert(
  self : MockTransaction,
  matcher : @mock_runtime.Matcher[(String, Int32)],
  value : Unit,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
) -> Unit {
  self.slot_insert.expect(matcher, _ => value, times~, sequence?)
}

///|
#warnings("-unused_value")
fn MockTransaction::respond_insert(
  self : MockTransaction,
  matcher : @mock_runtime.Matcher[(String, Int32)],
  action : ((String, Int32)) -> Unit raise DatabaseError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
) -> Unit {
  self.slot_insert.expect(matcher, action, times~, sequence?)
}

///|
#warnings("-unused_value")
fn MockTransaction::raise_insert(
  self : MockTransaction,
  matcher : @mock_runtime.Matcher[(String, Int32)],
  error : DatabaseError,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
) -> Unit {
  self.slot_insert.expect(matcher, _ => raise error, times~, sequence?)
}

///|
impl Transaction for MockTransaction with fn insert(self, arg_0, arg_1) {
  let args = (arg_0, arg_1)
  let action = self.slot_insert.take(args)
  action(args)
}

///|
#warnings("-unused_value")
fn MockTransaction::expect_commit(
  self : MockTransaction,
  matcher : @mock_runtime.Matcher[Unit],
  value : Unit,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
) -> Unit {
  self.slot_commit.expect(matcher, _ => value, times~, sequence?)
}

///|
#warnings("-unused_value")
fn MockTransaction::respond_commit(
  self : MockTransaction,
  matcher : @mock_runtime.Matcher[Unit],
  action : (Unit) -> Unit,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
) -> Unit {
  self.slot_commit.expect(matcher, action, times~, sequence?)
}

///|
impl Transaction for MockTransaction with fn commit(self) {
  let args = ()
  let action = self.slot_commit.take(args)
  action(args)
}

///|
#warnings("-unused_value")
fn MockTransaction::expect_rollback(
  self : MockTransaction,
  matcher : @mock_runtime.Matcher[Unit],
  value : Unit,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
) -> Unit {
  self.slot_rollback.expect(matcher, _ => value, times~, sequence?)
}

///|
#warnings("-unused_value")
fn MockTransaction::respond_rollback(
  self : MockTransaction,
  matcher : @mock_runtime.Matcher[Unit],
  action : (Unit) -> Unit,
  times~ : Int32 = 1,
  sequence? : @mock_runtime.Sequence,
) -> Unit {
  self.slot_rollback.expect(matcher, action, times~, sequence?)
}

///|
impl Transaction for MockTransaction with fn rollback(self) {
  let args = ()
  let action = self.slot_rollback.take(args)
  action(args)
}
