///|
pub suberror ServiceError {
  OfflineService
}

///|
pub(open) trait Reader: Named {
  fn lookup(Self, id~ : Int32) -> String raise ServiceError
}

///|
pub(open) trait Health: Named {
  fn ready(Self) -> Bool = _
}

///|
impl Health with fn ready(_self) {
  true
}
