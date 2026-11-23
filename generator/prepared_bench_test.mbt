///|
fn multi_trait_source(size : Int32) -> String {
  let source = StringBuilder()
  for index in 0..<size {
    let name = "Service" + index.to_string()
    source.write_string(
      "trait \{name} : Shared {\n" +
      "  fn load(Self, String, Int32) -> Array[String] raise\n" +
      "  fn count(Self, Array[(String, Int32)]) -> Int32\n" +
      "  async fn save(Self, item~ : String) -> Unit noraise\n" +
      "}\n",
    )
  }
  source.to_string()
}

///|
test "从同一文件生成1、4、16个 trait" (b : @bench.T) {
  let source = multi_trait_source(32)
  let filename = "services.mbt"
  let additional_sources = [
    ("shared.mbt", "trait Shared { fn health(Self) -> Bool }"),
  ]
  for size in [1, 4, 16] {
    let names = Array::makei(size, index => "Service" + index.to_string())
    let requests : Array[@generator.BatchRequest] = names.map(trait_name => {
      source,
      trait_name,
      filename,
      mock_name: None,
      additional_sources,
    })
    b.bench(name="重复解析/" + size.to_string(), () => {
      for name in names {
        let code = @generator.generate(
          source,
          name,
          filename~,
          additional_sources~,
        ) catch {
          @generator.GenerationError(message) => abort(message)
        }
        b.keep(code)
      }
    })
    b.bench(name="一次准备/" + size.to_string(), () => {
      let prepared = @generator.prepare_sources(
        source,
        filename~,
        additional_sources~,
      ) catch {
        @generator.GenerationError(message) => abort(message)
      }
      for name in names {
        let code = @generator.generate_prepared(prepared, name) catch {
          @generator.GenerationError(message) => abort(message)
        }
        b.keep(code)
      }
    })
    b.bench(name="批量请求/" + size.to_string(), () => {
      let results = @generator.generate_batch(requests) catch {
        @generator.GenerationError(message) => abort(message)
      }
      for result in results {
        guard result.generated is Some(code) else {
          abort(result.error.unwrap_or("基准输入应能生成源码"))
        }
        b.keep(code)
      }
    })
  }
}
