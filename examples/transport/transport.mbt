///|
pub suberror TransportError {
  Temporary
} derive(Debug)

///|
pub extend TransportError with Debug::{to_repr}

///|
pub(open) trait Transport {
  async fn fetch(Self, String) -> String raise TransportError
  async fn is_ready(Self) -> Bool noraise
  async fn close(Self) -> Unit
}

///|
pub async fn[T : Transport] fetch_with_retry(
  transport : T,
  path : String,
) -> String raise TransportError {
  if !Transport::is_ready(transport) {
    raise Temporary
  }
  Transport::fetch(transport, path) catch {
    Temporary => Transport::fetch(transport, path)
  }
}
