# moon-mock

moon-mock 把 MoonBit trait 生成类型安全的测试替身。测试可指定参数、次数、顺序、返回值和错误，用于隔离数据库、网络传输等依赖。生成结果是普通 MoonBit 源码，可直接与项目一起编译、审查和调试。

## 快速运行

准备与本项目验证一致的 MoonBit 工具链（`moonc v0.10.18+6c83a7f62`）。运行 JS 目标需要 Node.js，运行 native 目标需要平台的 C 工具链。 [MoonBit 安装说明](https://www.moonbitlang.com/download)

```sh
git clone https://github.com/dtzrttp/moon-mock.git
cd moon-mock
moon update
moon test --target js --deny-warn
```

在本仓库生成事务示例的 mock，在相同包的白盒测试中使用：

```sh
moon run --target native cmd/moon-mock -- generate examples/transaction/transaction.mbt Transaction --output examples/transaction/mock_transaction_wbtest.mbt
moon test examples/transaction --target native --deny-warn
```

省略 `--output` 可把源码写到标准输出。CI 可将其换成 `--check <文件>`，检查已提交的生成物是否过期。输出路径要以 `_wbtest.mbt` 结尾。已有文件须带生成标记才可覆盖。用法或过期检查失败返回 2，读取或生成失败返回 1。

## 在测试中使用

将生成文件放到 trait 所在包。在消费方的 `moon.pkg` 中把运行库加入白盒测试导入，并用固定别名：

```moonbit
import {
  "dtzrttp/moon-mock/runtime" @mock_runtime,
} for "wbtest"
```

本地接入时，把消费方和本仓库放在同一个 `moon.work` 的 `members` 中，再在消费方的 `moon.mod` 中写 `import { "dtzrttp/moon-mock@0.1.0" }`。独立消费方测试复现了该配置。生成器使用官方解析器，运行库本身无需导入解析器。 [MoonBit 工作区说明](https://docs.moonbitlang.com/en/latest/toolchain/moon/workspace.html)

下面的测试使用示例包的 `Transaction` trait。写入失败后，测试会确认业务代码回滚且没有提交。

```moonbit
test "失败后回滚" {
  @mock_runtime.with_mock(c => {
    let mock = MockTransaction::new(c)
    let order = @mock_runtime.Sequence::new()
    mock.expect_begin(@mock_runtime.any(), (), sequence=order)
    mock.raise_insert(@mock_runtime.equal_to(("bob", 30)), WriteFailed, sequence=order)
    mock.expect_rollback(@mock_runtime.any(), (), sequence=order)
    mock.expect_commit(@mock_runtime.any(), (), times=0)
    let result = Ok(transfer(mock, "bob", 30)) catch {
      error => Err(error)
    }
    assert_true(result is Err(WriteFailed))
  })
}
```

- `expect_*` 设置常量返回，`respond_*` 用类型化回调计算结果，`raise_*` 为可抛错方法设置错误。
- `any()` 接受任意参数，`equal_to(value)` 用 `Eq` 判断并用 `Debug` 展示实际值，`matching(描述, 谓词)` 可匹配不实现 `Eq` 的类型。零个参数以 `Unit` 表示，多个参数组成元组。
- `times` 默认为 1。指定 `Sequence` 后，同组按登记顺序匹配。调用开始时计数，异步回调挂起不改变顺序。可匹配多个预期时先选择最早登记、还有次数且顺序允许的预期。
- `with_mock` 和 `with_mock_async` 在测试体正常返回时核对遗漏调用。测试体的抛错或取消直接传播。意外调用立即失败，避免在 `noraise` 方法中返回伪造值或抛出 trait 外的错误。需要手动检查时可使用控制器的 `verify()` 或 `missing_calls()`。
- 应在异步作用域内等待所有使用 mock 的任务完成。参数谓词应无副作用。不同测试各用自己的控制器。

## 可运行示例

| 示例 | 测试的业务行为 | 复现 |
| --- | --- | --- |
| 事务 | 写入失败后回滚，成功时按顺序提交 | `moon test examples/transaction --target js --deny-warn` |
| 网络传输 | 暂时错误触发重试，异步回调挂起后返回，关闭连接可抛错 | `moon test examples/transport --target js --deny-warn` |

这两个示例使用项目自建的最小依赖接口。Exa SDK 的实际 `Transport` 源码可直接生成，moondb 的 `Driver` 目前会定位并拒绝默认方法。 [真实接口适配](docs/adoption.md) · [查重记录](docs/dedup.md)

## 支持范围

首版生成同包的 `Self` 接收者方法，支持位置参数、命名类型、泛型类型应用、可选类型和元组，覆盖同步方法和异步方法、具体或通用错误类型、异步默认错误和 `noraise`。适用类型与 trait 要可在同包测试中解析。标签参数、方法泛型、超 trait、默认实现、函数类型参数、条件错误、`nocancel` 和跨包 trait 生成属于后续范围。未支持的签名会报告源码位置。

## 验证与许可

CI 检查格式、静态检查、生成文件是否过期、JS/native 测试和 CLI 构建。可用 `node tools/cli-smoke.mjs js` 或 `node tools/cli-smoke.mjs native` 运行已构建的命令行验收，`node tools/consumer-smoke.mjs` 验证另一个 MoonBit 模块从生成到运行的流程。项目采用 Apache-2.0。 [来源与依赖许可](NOTICE.md)
