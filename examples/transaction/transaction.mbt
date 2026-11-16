///|
pub suberror DatabaseError {
  WriteFailed
} derive(Debug)

///|
pub extend DatabaseError with Debug::{to_repr}

///|
pub(open) trait Transaction {
  fn begin(Self) -> Unit
  fn insert(Self, String, Int32) -> Unit raise DatabaseError
  fn commit(Self) -> Unit
  fn rollback(Self) -> Unit
}

///|
pub fn[T : Transaction] transfer(
  tx : T,
  account : String,
  amount : Int32,
) -> Unit raise DatabaseError {
  Transaction::begin(tx)
  errdefer Transaction::rollback(tx)
  Transaction::insert(tx, account, amount)
  Transaction::commit(tx)
}
