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

省略 `--output` 可把源码写到标准输出。CI 可将其换成 `--check <文件>`，检查已提交的生成物是否过期。包内已有同名测试替身时，可加 `--mock-name GeneratedTransaction` 指定类型名。输出路径要以 `_wbtest.mbt` 结尾。已有文件须带生成标记才可覆盖。用法或过期检查失败返回 2，读取或生成失败返回 1。

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
- 生成的替身会显式覆盖带默认实现的方法。与其他方法一样，调用前须登记预期，未登记的调用会失败。
- `any()` 接受任意参数，`equal_to(value)` 用 `Eq` 判断并用 `Debug` 展示实际值，`matching(描述, 谓词)` 可匹配不实现 `Eq` 的类型。零个参数以 `Unit` 表示，多个参数组成元组。
- 方法参数是函数时，可以用 `any()` 接收回调，再在 `respond_*` 中用测试数据调用它。方法返回函数时，可以在 `expect_*` 中提供测试用的函数。
- 标签参数在调用处沿用原名，匹配器和回调按 trait 声明顺序接收值。例如 `fn find(Self, String, limit? : Int32) -> Int32` 的匹配值是 `("书", Some(10))`，省略 `limit` 时是 `("书", None)`。
- `times` 默认为 1，也可用 `count` 指定 `CallCount::between(min, max)` 或 `CallCount::at_least(min)`。使用 `count` 时，`times` 保持默认值。顺序组中，前一步达到下限后允许进入下一步，下一步一旦匹配就不能回到前一步。调用开始时计数，异步回调挂起不会改变顺序。可匹配多个预期时优先选择最早登记、尚有余量且顺序允许的预期。
- `with_mock` 和 `with_mock_async` 在测试体正常返回时核对遗漏调用。测试体的抛错或取消直接传播。意外调用立即失败，避免在 `noraise` 方法中返回伪造值或抛出 trait 外的错误。需要手动检查时可使用控制器的 `verify()` 或 `missing_calls()`。
- 应在异步作用域内等待所有使用 mock 的任务完成。参数谓词应无副作用。不同测试各用自己的控制器。

## 从同包的多个文件生成继承 mock

目标 trait 在第一个文件中声明。可以重复传入 `--source` 补充同包父 trait 的源文件。生成的类型实现整个继承链，共用祖先只登记一次预期。

```sh
moon-mock generate service.mbt Service \
  --source branch_traits.mbt \
  --source base_traits.mbt \
  --output mock_service_wbtest.mbt
```

例如，测试最多允许一次就绪探测，读取操作至少执行两次。

```moonbit
mock.expect_ready(@mock_runtime.any(), true, count=@mock_runtime.CallCount::between(0, 1))
mock.expect_lookup(@mock_runtime.equal_to(42), "book", count=@mock_runtime.CallCount::at_least(2))
```

## 可运行示例

| 示例 | 测试的业务行为 | 复现 |
| --- | --- | --- |
| 事务 | 写入失败后回滚，成功时按顺序提交 | `moon test examples/transaction --target js --deny-warn` |
| 网络传输 | 暂时错误触发重试，异步回调挂起后返回，关闭连接可抛错 | `moon test examples/transport --target js --deny-warn` |

在两个真实项目的固定版本中也跑通了离线接入测试。Exa SDK 使用生成的传输层替身验证客户端如何处理 401。moondb 使用生成的 `Driver` 验证事务回滚和游标读取。 [测试结果与复现步骤](docs/adoption.md) · [查重记录](docs/dedup.md)

## 支持范围

生成器支持同包的 `Self` 接收者方法，覆盖位置参数、必填与可省略的标签参数、命名类型、泛型类型应用、`&Trait` 对象、可选类型、元组及函数类型。同步和异步方法可具有默认实现。方法与嵌套函数类型各自保留同步或异步语义以及抛错效果，支持具体或通用错误类型、异步默认错误和 `noraise`。签名中的类型需要能在同包测试中解析。支持从同包多份源码解析超 trait。循环、缺失或重复声明，以及继承链中不同 trait 声明的同名方法会报告源码位置。方法泛型、条件错误、`nocancel` 和跨包 trait 生成属于后续范围。

## 验证与许可

CI 检查格式、静态检查、生成文件是否过期、JS/native 测试和 CLI 构建。构建后执行 `node tools/cli-smoke.mjs js` 和 `node tools/cli-smoke.mjs native` 验收 CLI。`node tools/consumer-smoke.mjs js` 和 `node tools/consumer-smoke.mjs native` 验证另一个 MoonBit 模块从生成到运行的流程。项目采用 Apache-2.0。 [来源与依赖许可](NOTICE.md)
