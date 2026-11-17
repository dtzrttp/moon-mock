///|
pub(open) trait Availability {
  fn available(Self) -> Bool
}

///|
pub suberror ReadError {
  Offline
}

///|
pub(open) trait Catalog {
  fn lookup(Self, Int32) -> (String, Int32)?
  fn status(Self, &Availability) -> &Availability = _
  fn search(
    Self,
    String,
    action~ : Int32,
    arg_0~ : Int32,
    self~ : Int32,
    args~ : Int32,
  ) -> Int32
  fn page_size(Self, limit? : Int32) -> Int32
  fn apply(Self, (Int32) -> Int32, Int32) -> Int32
  fn fetcher(Self) -> () -> Int32 raise ReadError
  async fn fetch_with(Self, async (Int32) -> Int32 raise ReadError) -> Int32 raise ReadError
}

///|
impl Catalog with fn status(_self, fallback) {
  fallback
}
