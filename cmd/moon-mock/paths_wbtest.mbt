///|
test "清单输出拒绝父目录逃逸和绝对路径" {
  let base = @path.Path(".").resolve().to_string()
  let absolute = @path.Path(base)
    .join(@path.Path("mock_wbtest.mbt"))
    .to_string()
  for name in ["../mock_wbtest.mbt", "sub/../../mock_wbtest.mbt", absolute] {
    let result = Ok(confined_output(base, name)) catch {
      UsageError(message) => Err(message)
    }
    guard result is Err(message) else { fail("越界输出应拒绝") }
    assert_true(message.contains("manifest_invalid"))
  }
}

///|
test "普通子目录输出规范化后保留在清单目录内" {
  let base = @path.Path(".").resolve().to_string()
  let first = confined_output(base, "mock_wbtest.mbt")
  let alternate = confined_output(base, "nested/../mock_wbtest.mbt")
  assert_eq(path_key(first), path_key(alternate))
  let child = confined_output(base, "nested/mock_wbtest.mbt")
  assert_true(child.contains("nested"))
}

///|
test "输出后缀限制防止误写普通源文件或目录" {
  let base = @path.Path(".").resolve().to_string()
  for name in ["file.mbt", "file_test.mbt", "file.txt", "_wbtest.mbt/", "."] {
    let result = Ok(confined_output(base, name)) catch {
      UsageError(message) => Err(message)
    }
    assert_true(result is Err(_))
  }
}

///|
test "路径比较处理点和父目录段" {
  assert_eq(path_key("same_wbtest.mbt"), path_key("./same_wbtest.mbt"))
  assert_eq(path_key("same_wbtest.mbt"), path_key("sub/../same_wbtest.mbt"))
  assert_false(path_key("first_wbtest.mbt") == path_key("second_wbtest.mbt"))
  if @path.sep == '\\' {
    assert_eq(path_key("Same_wbtest.mbt"), path_key("same_wbtest.mbt"))
  }
}

///|
test "绝对输入路径不会再次拼接到清单目录" {
  let base = @path.Path(".").resolve().to_string()
  let absolute = @path.Path(base).join(@path.Path("input.mbt")).to_string()
  assert_eq(path_key(manifest_path(base, absolute)), path_key(absolute))
  assert_eq(path_key(manifest_path(base, "input.mbt")), path_key(absolute))
}

///|
test "版本号必须是整数字面量1而非浮点舍入结果" {
  for version in ["1.00000000000000001", "1.0", "1e0"] {
    reject_manifest(
      "{\"schema_version\":" + version + ",\"jobs\":[]}",
      "/schema_version",
    )
  }
}

///|
test "任务对象和可选名称类型错误均可定位" {
  reject_manifest("{\"schema_version\":1,\"jobs\":[true]}", "/jobs/0")
  for name in ["null", "5", "[]", "{}", "\"\""] {
    reject_manifest(
      "{\"schema_version\":1,\"jobs\":[{\"source\":\"a.mbt\",\"trait\":\"A\",\"output\":\"a_wbtest.mbt\",\"mock_name\":" +
      name +
      "}]}",
      "/mock_name",
    )
  }
}

///|
test "辅助文件数量和JSON嵌套有独立资源限制" {
  let extras = Array::make(257, Json::string("a.mbt"))
  let manifest : Json = {
    "schema_version": 1,
    "jobs": [
      {
        "source": "s.mbt",
        "trait": "S",
        "output": "s_wbtest.mbt",
        "sources": Json::array(extras),
      },
    ],
  }
  reject_manifest(manifest.stringify(), "256")
  let mut nested = "0"
  for _ in 0..<33 {
    nested = "[" + nested + "]"
  }
  reject_manifest(nested, "JSON")
}

///|
test "最大任务数组可解析而输入数组对象互不混淆" {
  let jobs = []
  for i in 0..<256 {
    let item : Json = {
      "source": "s" + i.to_string() + ".mbt",
      "trait": "S" + i.to_string(),
      "output": "s" + i.to_string() + "_wbtest.mbt",
    }
    jobs.push(item)
  }
  let manifest : Json = { "schema_version": 1, "jobs": Json::array(jobs) }
  let parsed = parse_manifest(manifest.stringify())
  assert_eq(parsed.length(), 256)
  assert_eq(parsed[0].trait_name, "S0")
  assert_eq(parsed[255].trait_name, "S255")
  assert_false(parsed[0].output == parsed[255].output)
}
