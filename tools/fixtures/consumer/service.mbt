///|
pub(open) trait Endpoint: Reader + Health + Marker {
  fn close(Self) -> Unit
}

///|
pub(open) trait Service: Endpoint {}
