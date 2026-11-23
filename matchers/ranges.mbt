///|
fn interval_text(minimum : Int32, maximum : Int32) -> String {
  "[\{minimum}, \{maximum}]"
}

///|
fn validate_range(
  subject : String,
  minimum : Int32,
  maximum : Int32,
  nonnegative~ : Bool = false,
) -> Result[Unit, @runtime.CallFailure] {
  if nonnegative && minimum < 0 {
    return Err(
      @runtime.CallFailure::new(
        "invalid_range",
        "\{subject}的下限必须非负，收到 \{interval_text(minimum, maximum)}",
      ),
    )
  }
  if maximum < minimum {
    return Err(
      @runtime.CallFailure::new(
        "invalid_range",
        "\{subject}的上限不得小于下限，收到 \{interval_text(minimum, maximum)}",
      ),
    )
  }
  Ok(())
}

///|
fn in_range(value : Int32, minimum : Int32, maximum : Int32) -> Bool {
  minimum <= value && value <= maximum
}
