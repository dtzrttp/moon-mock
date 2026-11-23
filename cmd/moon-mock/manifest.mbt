///|
priv struct ManifestJob {
  source : String
  trait_name : String
  output : String
  mock_name : String?
  sources : Array[String]
}

///|
fn manifest_error(path : String, rule : String) -> Unit raise UsageError {
  raise UsageError("manifest_invalid: " + path + ": " + rule)
}

///|
fn known_fields(
  object : Map[String, Json],
  allowed : Array[String],
  path : String,
) -> Unit raise UsageError {
  let unknown = []
  for name, _ in object {
    if !allowed.contains(name) {
      unknown.push(name)
    }
  }
  unknown.sort()
  if !unknown.is_empty() {
    manifest_error(path, "未知字段：" + unknown.join("、"))
  }
}

///|
fn manifest_string(value : Json?, path : String) -> String raise UsageError {
  guard value is Some(String(text)) else {
    manifest_error(path, "需要非空字符串")
    return ""
  }
  if text.trim().is_empty() ||
    text.contains("\u{0000}") ||
    text.contains("\n") ||
    text.contains("\r") {
    manifest_error(path, "需要不含NUL和换行的非空字符串")
  }
  text
}

///|
/// 解析受控清单；重复JSON字段、未知字段均拒绝，防止配置拼写错误被忽略。
fn parse_manifest(source : String) -> Array[ManifestJob] raise UsageError {
  if source.length() > 1048576 {
    manifest_error("/", "清单文本最多1048576个UTF-16编码单位")
  }
  let json = @json.parse(
    source[:],
    max_nesting_depth=32,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    error => {
      manifest_error("/", "JSON解析失败：" + @debug.to_string(error))
      Json::null()
    }
  }
  guard json is Object(root) else {
    manifest_error("/", "需要JSON对象")
    return []
  }
  known_fields(root, ["schema_version", "jobs"], "/")
  guard root.get("schema_version") is Some(Number(_, repr=Some("1"))) else {
    manifest_error("/schema_version", "只支持整数字面量1")
    return []
  }
  guard root.get("jobs") is Some(Array(jobs)) else {
    manifest_error("/jobs", "需要任务数组")
    return []
  }
  if jobs.length() > 256 {
    manifest_error("/jobs", "一次最多256项任务")
  }
  let result = []
  for index, value in jobs {
    let path = "/jobs/" + index.to_string()
    guard value is Object(fields) else {
      manifest_error(path, "任务需要JSON对象")
      continue
    }
    known_fields(
      fields,
      ["source", "trait", "output", "mock_name", "sources"],
      path,
    )
    let source = manifest_string(fields.get("source"), path + "/source")
    let trait_name = manifest_string(fields.get("trait"), path + "/trait")
    let output = manifest_string(fields.get("output"), path + "/output")
    let mock_name = match fields.get("mock_name") {
      None => None
      Some(value) => Some(manifest_string(Some(value), path + "/mock_name"))
    }
    let sources = []
    match fields.get("sources") {
      None => ()
      Some(Array(extra)) => {
        if extra.length() > 256 {
          manifest_error(path + "/sources", "辅助源码最多256项")
        }
        for extra_index, value in extra {
          let file = manifest_string(
            Some(value),
            path + "/sources/" + extra_index.to_string(),
          )
          if sources.contains(file) {
            manifest_error(path + "/sources", "重复辅助源码：" + file)
          }
          sources.push(file)
        }
      }
      Some(_) => manifest_error(path + "/sources", "需要字符串数组")
    }
    result.push({ source, trait_name, output, mock_name, sources, })
  }
  result
}

///|
fn manifest_path(base : String, name : String) -> String {
  let path = @path.Path(name)
  if path.is_absolute() {
    path.resolve().to_string()
  } else {
    @path.Path(base).join(path).resolve().to_string()
  }
}

///|
/// 输出采用便于跨平台复现的文件名子集，预先拒绝Windows禁用字符和设备名。
fn portable_output_name(name : String) -> Unit raise UsageError {
  let normalized_name = name.replace_all(old="\\", new="/")
  for part in normalized_name.split("/") {
    if part == "." || part == ".." {
      continue
    }
    let segment = part.to_owned()
    if segment.has_suffix(".") || segment.has_suffix(" ") {
      manifest_error("/output", "路径段不能以点或空格结尾")
    }
    for char in segment {
      if char < ' ' || "<>:\"|?*".contains(char.to_string()) {
        manifest_error("/output", "输出路径含跨平台禁用字符")
      }
    }
    let stem = segment.split(".").next().unwrap_or("").to_owned().to_upper()
    if [
        "CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6",
        "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7",
        "LPT8", "LPT9",
      ].contains(stem) {
      manifest_error("/output", "输出路径使用了保留设备名称")
    }
  }
}

///|
/// 将输出限制在清单所在目录内；这是一项路径规则，不声称提供符号链接沙箱。
fn confined_output(base : String, name : String) -> String raise UsageError {
  if name.has_suffix("/") || name.has_suffix("\\") {
    manifest_error(
      "/output", "输出应为文件路径，不能以目录分隔符结尾",
    )
  }
  if @path.Path(name).is_absolute() {
    manifest_error("/output", "输出必须是清单目录内的相对路径")
  }
  portable_output_name(name)
  let output = manifest_path(base, name)
  let relative = @path.Path(output)
    .relative(base=@path.Path(base).resolve())
    .to_string()
  if relative == ".." ||
    relative.has_prefix("../") ||
    relative.has_prefix("..\\") ||
    @path.Path(relative).is_absolute() {
    manifest_error("/output", "输出不能越过清单目录")
  }
  if !output.has_suffix("_wbtest.mbt") {
    manifest_error("/output", "输出必须以_wbtest.mbt结尾")
  }
  output
}
