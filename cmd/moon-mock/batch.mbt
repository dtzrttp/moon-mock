///|
priv struct PreparedJob {
  request : @generator.BatchRequest
  output : String
}

///|
/// 单次批处理最多缓存1024个输入文件、合计64MiB，避免清单放大内存占用。
let batch_max_source_files : Int32 = 1024

///|
let batch_max_source_bytes : Int32 = 67108864

///|
fn read_cached_source(
  path : String,
  cache : Map[String, String],
  total_bytes : Ref[Int32],
) -> String raise {
  let key = path_key(path)
  match cache.get(key) {
    Some(source) => source
    None => {
      if cache.length() >= batch_max_source_files {
        raise UsageError(
          "batch_source_limit: 一次最多读取1024个不同源码文件",
        )
      }
      let source = read_source(path)
      let size = @utf8.encode(source).length()
      if total_bytes.val > batch_max_source_bytes - size {
        raise UsageError(
          "batch_source_limit: 一次批处理源码总量最多67108864字节",
        )
      }
      total_bytes.val += size
      cache.set(key, source)
      source
    }
  }
}

///|
fn check_output_file(
  output : String,
  input_contents : Map[String, Unit],
) -> Unit raise {
  if @fs.path_exists(output) {
    if !@fs.is_file(output) {
      raise UsageError("output_not_file: " + output)
    }
    let previous = @fs.read_file_to_string(output)
    if input_contents.contains(previous) {
      raise UsageError(
        "source_output_alias: 输出内容与某个输入完全相同，拒绝覆盖潜在硬链接：" +
        output,
      )
    }
    if !previous.trim_start().has_prefix("// 由 moon-mock 生成") {
      raise UsageError(
        "refuse_overwrite: 拒绝覆盖非生成文件：" + output,
      )
    }
    if contains_trait(previous) {
      raise UsageError(
        "source_output_conflict: 输出包含trait声明：" + output,
      )
    }
  }
  let parent = @path.Path(output).dirname().to_string()
  if !@fs.path_exists(parent) || !@fs.is_dir(parent) {
    raise UsageError(
      "output_parent_missing: 输出父目录需预先存在：" + parent,
    )
  }
}

///|
/// 所有输入先读取、所有输出先预检，避免后面的清单错误导致前面的文件已改写。
fn prepare_jobs(
  base : String,
  jobs : Array[ManifestJob],
) -> Array[PreparedJob] raise {
  let prepared = []
  let inputs : Array[String] = []
  let outputs : Array[String] = []
  let source_cache : Map[String, String] = Map([])
  let input_contents : Map[String, Unit] = Map([])
  let total_source_bytes = Ref(0)
  for job in jobs {
    let file = manifest_path(base, job.source)
    if !file.has_suffix(".mbt") {
      manifest_error("/source", "源码需以.mbt结尾")
    }
    let output = confined_output(base, job.output)
    let key = path_key(output)
    if outputs.contains(key) {
      raise UsageError("duplicate_output: " + output)
    }
    outputs.push(key)
    inputs.push(path_key(file))
    let source = read_cached_source(file, source_cache, total_source_bytes)
    input_contents.set(source, ())
    let additional_sources = []
    let extra_keys : Array[String] = []
    for extra in job.sources {
      let extra_file = manifest_path(base, extra)
      if !extra_file.has_suffix(".mbt") {
        manifest_error("/sources", "辅助源码需以.mbt结尾")
      }
      let extra_key = path_key(extra_file)
      if extra_key == path_key(file) || extra_keys.contains(extra_key) {
        raise UsageError("duplicate_source: " + extra_file)
      }
      inputs.push(extra_key)
      extra_keys.push(extra_key)
      let extra_source = read_cached_source(
        extra_file, source_cache, total_source_bytes,
      )
      input_contents.set(extra_source, ())
      additional_sources.push((extra_file, extra_source))
    }
    let request : @generator.BatchRequest = {
      source,
      trait_name: job.trait_name,
      filename: file,
      mock_name: job.mock_name,
      additional_sources,
    }
    prepared.push({ request, output, })
  }
  for item in prepared {
    if inputs.contains(path_key(item.output)) {
      raise UsageError(
        "source_output_conflict: 输出与清单中某个输入相同：" +
        item.output,
      )
    }
    check_output_file(item.output, input_contents)
  }
  prepared
}

///|
fn batch_report(
  items : Array[PreparedJob],
  results : Array[@generator.BatchResult],
  states : Array[String],
  file_errors : Array[String?],
) -> Json {
  let rows : Array[Json] = []
  for index, result in results {
    rows.push({
      "index": result.index,
      "trait": result.trait_name,
      "source": result.filename,
      "output": items[index].output,
      "status": states[index],
      "error": match result.error {
        Some(message) => Json::string(message)
        None =>
          match file_errors[index] {
            Some(message) => Json::string(message)
            None => Json::null()
          }
      },
    })
  }
  { "schema_version": 1, "jobs": Json::array(rows) }
}

///|
fn batch_command(manifest : String, check : Bool) -> Unit raise {
  let jobs = parse_manifest(read_source(manifest))
  let base = @path.Path(manifest).resolve().dirname().to_string()
  let items = prepare_jobs(base, jobs)
  let requests = items.map(item => item.request)
  let results = @generator.generate_batch(requests)
  let states = results.map(result => {
    if result.error is Some(_) {
      "failed"
    } else {
      "ready"
    }
  })
  let file_errors : Array[String?] = Array::make(results.length(), None)
  if results.iter().any(result => result.error is Some(_)) {
    println(
      batch_report(items, results, states, file_errors).stringify(indent=2),
    )
    raise BatchError(
      "batch_failed: 至少一项生成失败，未写入任何输出",
    )
  }
  if check {
    let mut stale = false
    for index, item in items {
      guard results[index].generated is Some(generated) else { continue }
      if !@fs.path_exists(item.output) ||
        normalized(@fs.read_file_to_string(item.output)) !=
        normalized(generated) {
        states[index] = "out_of_date"
        stale = true
      } else {
        states[index] = "current"
      }
    }
    println(
      batch_report(items, results, states, file_errors).stringify(indent=2),
    )
    if stale {
      raise UsageError(
        "generated_out_of_date: 批量检查发现缺失或过期文件",
      )
    }
  } else {
    for index in 0..<states.length() {
      states[index] = "not_attempted"
    }
    let mut write_failure : String? = None
    for index, item in items {
      guard results[index].generated is Some(generated) else { continue }
      states[index] = "writing"
      @fs.write_string_to_file(item.output, generated) catch {
        @fs.IOError(message) => {
          states[index] = "failed"
          file_errors[index] = Some(message)
          write_failure = Some(message)
        }
      }
      if write_failure is Some(_) {
        break
      }
      states[index] = "written"
    }
    if write_failure is Some(message) {
      println(
        batch_report(items, results, states, file_errors).stringify(indent=2),
      )
      raise BatchError(
        "batch_write_partial: 写入失败；written、failed和not_attempted表示各输出的实际状态：" +
        message,
      )
    }
    println(
      batch_report(items, results, states, file_errors).stringify(indent=2),
    )
  }
}
