///|
test "解析生成格式化1、16、64个方法" (b : @bench.T) {
  for size in [1, 16, 64] {
    let source = StringBuilder()
    source.write_string("trait Repository {\n")
    for i in 0..<size {
      source.write_string(
        "fn query_" +
        i.to_string() +
        "(Self, String, Array[Int32]) -> Array[String] raise DbError\n",
      )
    }
    source.write_string("}")
    let text = source.to_string()
    b.bench(name="生成方法数/" + size.to_string(), () => {
      let generated = @generator.generate(text, "Repository") catch {
        error =>
          abort("基准输入应当能生成：" + error.to_repr().to_string())
      }
      b.keep(generated)
    })
  }
}
