///|
fn reject_manifest(source : String, fragment : String) -> Unit raise {
  let result = Ok(parse_manifest(source)) catch {
    UsageError(message) => Err(message)
  }
  guard result is Err(message) else { fail("清单应当被拒绝") }
  assert_true(message.contains("manifest_invalid"))
  assert_true(message.contains(fragment))
}

///|
test "批量清单保留任务及辅助文件顺序" {
  let jobs = parse_manifest(
    (
      #|{"schema_version":1,"jobs":[
      #| {"source":"数据库.mbt","trait":"Store","output":"mock_store_wbtest.mbt","mock_name":"GeneratedStore","sources":["b.mbt","a.mbt"]},
      #| {"source":"reader.mbt","trait":"Reader","output":"mock_reader_wbtest.mbt"}
      #|]}
    ),
  )
  assert_eq(jobs.length(), 2)
  assert_eq(jobs[0].source, "数据库.mbt")
  assert_eq(jobs[0].mock_name, Some("GeneratedStore"))
  assert_eq(jobs[0].sources, ["b.mbt", "a.mbt"])
  assert_eq(jobs[1].trait_name, "Reader")
  assert_eq(jobs[1].mock_name, None)
  assert_eq(jobs[1].sources, [])
}

///|
test "批量清单拒绝损坏JSON、重复字段及未知字段" {
  for input in ["", "{", "[]", "null", "true"] {
    reject_manifest(input, "manifest_invalid")
  }
  reject_manifest(
    "{\"schema_version\":1,\"schema_version\":1,\"jobs\":[]}", "JSON",
  )
  reject_manifest("{\"schema_version\":1,\"jobs\":[],\"typo\":true}", "typo")
  reject_manifest("{\"schema_version\":1,\"jobs\":[],\"z\":0,\"a\":0}", "a、z")
}

///|
test "批量清单版本及任务容器必须精确匹配" {
  for version in ["null", "true", "\"1\"", "0", "2", "1.5"] {
    reject_manifest(
      "{\"schema_version\":" + version + ",\"jobs\":[]}",
      "/schema_version",
    )
  }
  reject_manifest("{\"jobs\":[]}", "/schema_version")
  for jobs in ["null", "{}", "1", "\"jobs\""] {
    reject_manifest("{\"schema_version\":1,\"jobs\":" + jobs + "}", "/jobs")
  }
  assert_eq(parse_manifest("{\"schema_version\":1,\"jobs\":[]}").length(), 0)
}

///|
test "每项任务的必填字段、类型和非空要求可定位" {
  for field in ["source", "trait", "output"] {
    let fields : Map[String, Json] = {
      "source": Json::string("s.mbt"),
      "trait": Json::string("Source"),
      "output": Json::string("mock_s_wbtest.mbt"),
    }
    fields.remove(field) |> ignore
    let manifest : Json = {
      "schema_version": 1,
      "jobs": [Json::object(fields)],
    }
    reject_manifest(manifest.stringify(), "/jobs/0/" + field)
    for invalid in [Json::null(), Json::number(3.0), Json::string("  ")] {
      fields[field] = invalid
      let manifest : Json = {
        "schema_version": 1,
        "jobs": [Json::object(fields)],
      }
      reject_manifest(manifest.stringify(), "/jobs/0/" + field)
    }
  }
}

///|
test "辅助文件数组的错误保留元素路径" {
  for
    (sources, path) in [
      ("null", "/sources"),
      ("{}", "/sources"),
      ("[1]", "/sources/0"),
      ("[\"\"]", "/sources/0"),
      ("[\"a.mbt\",\"a.mbt\"]", "重复"),
    ] {
    reject_manifest(
      "{\"schema_version\":1,\"jobs\":[{\"source\":\"a.mbt\",\"trait\":\"A\",\"output\":\"a_wbtest.mbt\",\"sources\":" +
      sources +
      "}]}",
      path,
    )
  }
}

///|
test "清单资源上限和非法路径字符被拒绝" {
  let item : Json = {
    "source": "s.mbt",
    "trait": "S",
    "output": "s_wbtest.mbt",
  }
  let jobs = Array::make(257, item)
  let manifest : Json = { "schema_version": 1, "jobs": Json::array(jobs) }
  reject_manifest(manifest.stringify(), "256")
  for value in ["\n", "a\rb", "a\u{0000}b"] {
    let manifest : Json = {
      "schema_version": 1,
      "jobs": [{ "source": value, "trait": "S", "output": "s_wbtest.mbt" }],
    }
    reject_manifest(manifest.stringify(), "/source")
  }
}
