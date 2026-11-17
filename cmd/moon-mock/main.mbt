///|
priv suberror UsageError {
  UsageError(String)
}

///|
let usage =
  #|用法：
  #|  moon-mock generate <文件.mbt> <Trait> [--mock-name <类型名>]
  #|      [--source <同包辅助源码.mbt>]...
  #|      [--output <生成文件_wbtest.mbt> | --check <生成文件_wbtest.mbt>]
  #|  moon-mock --help

///|
#cfg(target="js")
fn argument_start() -> Int32 {
  2
}

///|
#cfg(target="native")
fn argument_start() -> Int32 {
  1
}

///|
fn normalized(source : String) -> String {
  source.replace_all(old="\r\n", new="\n")
}

///|
fn read_source(path : String) -> String raise @fs.IOError {
  @fs.read_file_to_string(path) catch {
    @fs.IOError(message) =>
      raise @fs.IOError("source_read_error: \{path}: \{message}")
  }
}

///|
fn run(args : ArrayView[String]) -> Unit raise {
  if args is ["--help"] || args is ["-h"] {
    println(usage)
    return
  }
  guard args is ["generate", source_file, trait_name, .. options] else {
    raise UsageError(usage)
  }
  if options.length() % 2 != 0 {
    raise UsageError(usage)
  }
  let mut mode : (String, String)? = None
  let mut mock_name : String? = None
  let extra_files : Array[String] = []
  for i = 0; i < options.length(); i = i + 2 {
    let option = options[i]
    let value = options[i + 1]
    match option {
      "--source" if !extra_files.contains(value) && value != source_file =>
        extra_files.push(value)
      "--mock-name" if mock_name is None => mock_name = Some(value)
      "--output" | "--check" if mode is None => mode = Some((option, value))
      _ => raise UsageError("未知、重复或冲突的选项：" + option)
    }
  }
  if !source_file.has_suffix(".mbt") {
    raise UsageError("输入必须是 .mbt 文件")
  }
  let source = read_source(source_file)
  let additional_sources = []
  for path in extra_files {
    if !path.has_suffix(".mbt") {
      raise UsageError("辅助源码必须是 .mbt 文件：" + path)
    }
    additional_sources.push((path, read_source(path)))
  }
  let generated = @generator.generate(
    source,
    trait_name,
    filename=source_file,
    mock_name?,
    additional_sources~,
  )
  match mode {
    None => println(generated.trim_end().to_owned())
    Some((option, output)) => {
      if !output.has_suffix("_wbtest.mbt") ||
        source_file == output ||
        extra_files.contains(output) {
        raise UsageError("输出必须是独立的 *_wbtest.mbt 文件")
      }
      if option == "--check" {
        if !@fs.path_exists(output) ||
          !@fs.is_file(output) ||
          normalized(@fs.read_file_to_string(output)) != normalized(generated) {
          raise UsageError("generated_out_of_date: " + output)
        }
      } else {
        if @fs.path_exists(output) &&
          !@fs.read_file_to_string(output)
          .trim_start()
          .has_prefix("// 由 moon-mock 生成") {
          raise UsageError("拒绝覆盖非生成文件：" + output)
        }
        @fs.write_string_to_file(output, generated)
      }
    }
  }
}

///|
fn main {
  let args = @env.args()
  run(args[argument_start():]) catch {
    UsageError(message) => {
      eprintln(message)
      @sys.exit(2)
    }
    @generator.GenerationError(message) => {
      eprintln(message)
      @sys.exit(1)
    }
    @fs.IOError(message) => {
      eprintln(message)
      @sys.exit(1)
    }
    error => {
      eprintln(@debug.to_string(error))
      @sys.exit(1)
    }
  }
}
