///|
fn inspect_command(file : String, options : ArrayView[String]) -> Unit raise {
  let as_json = match options {
    [] => false
    ["--json"] => true
    _ => raise UsageError(usage)
  }
  if !file.has_suffix(".mbt") {
    raise UsageError("输入必须是.mbt源码")
  }
  let source = read_source(file) catch {
    @fs.IOError(message) => {
      if as_json {
        let diagnostic : Json = {
          "code": "source_read_error",
          "message": message,
          "filename": file,
          "line": Json::null(),
          "column": Json::null(),
        }
        let report : Json = {
          "schema_version": 1,
          "file": file,
          "traits": Json::array([]),
          "diagnostics": Json::array([diagnostic]),
          "type_checked": false,
        }
        println(report.stringify(indent=2))
      }
      raise BatchError(message)
    }
  }
  let traits = match @generator.try_inspect_source(source, filename=file) {
    Ok(traits) => traits
    Err(diagnostics) => {
      if as_json {
        let report : Json = {
          "schema_version": 1,
          "file": file,
          "traits": Json::array([]),
          "diagnostics": Json(diagnostics),
          "type_checked": false,
        }
        println(report.stringify(indent=2))
      }
      raise BatchError(diagnostics.map(item => item.text()).join("\n"))
    }
  }
  if as_json {
    let report : Json = {
      "schema_version": 1,
      "file": file,
      "traits": Json(traits),
      "type_checked": false,
      "diagnostics": Json::array([]),
    }
    println(report.stringify(indent=2))
  } else {
    println(
      "trait清单（语法检查，不等同于类型检查）：" + file,
    )
    for declaration in traits {
      println("\{declaration.name} @ \{declaration.line}:\{declaration.column}")
      if !declaration.parents.is_empty() {
        println("  继承：" + declaration.parents.join("、"))
      }
      for item in declaration.methods {
        let effect = if item.async_ { "异步" } else { "同步" }
        println(
          "  \{item.name}：\{effect}，\{item.parameter_count}个声明参数（含Self）",
        )
      }
    }
  }
}
