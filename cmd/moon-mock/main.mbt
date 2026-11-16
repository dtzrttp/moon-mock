///|
priv suberror UsageError {
  UsageError(String)
}

///|
let usage =
  #|用法：
  #|  moon-mock generate <文件.mbt> <Trait> [--output <生成文件_wbtest.mbt>]
  #|  moon-mock generate <文件.mbt> <Trait> --check <生成文件_wbtest.mbt>
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
fn run(args : ArrayView[String]) -> Unit raise {
  if args is ["--help"] || args is ["-h"] {
    println(usage)
    return
  }
  let (source_file, trait_name, mode) = match args {
    ["generate", source, trait_name] => (source, trait_name, None)
    ["generate", source, trait_name, option, output] if option == "--output" ||
      option == "--check" => (source, trait_name, Some((option, output)))
    _ => raise UsageError(usage)
  }
  if !source_file.has_suffix(".mbt") {
    raise UsageError("输入必须是 .mbt 文件")
  }
  let source = @fs.read_file_to_string(source_file)
  let generated = @generator.generate(source, trait_name, filename=source_file)
  match mode {
    None => println(generated.trim_end().to_owned())
    Some((option, output)) => {
      if !output.has_suffix("_wbtest.mbt") || source_file == output {
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
