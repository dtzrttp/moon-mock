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

## 安装到自己的项目

从 Mooncakes 安装固定版本的 native CLI 到指定目录，并在使用方添加运行库依赖。

```sh
moon install dtzrttp/moon-mock/cmd/moon-mock@0.2.0 --bin ./.bin
moon add dtzrttp/moon-mock@0.2.0
```

执行时，Linux/macOS 使用 `./.bin/moon-mock`，Windows 使用 `.\.bin\moon-mock.exe`。命令行生成器需要平台 C 工具链，生成结果及运行库已验证 JS 和 native。也可以按照下文的工作区方式使用本地源码。

```sh
./.bin/moon-mock generate traits.mbt Repository --output mock_repository_wbtest.mbt
moon test --target js --deny-warn
```

其中 `traits.mbt` 和 `Repository` 替换为自己的源码文件及 trait 名称，白盒测试导入见下一节。在本仓库执行 `node tools/registry-smoke.mjs 0.2.0` 可以从公开注册表下载、安装 CLI，并在全新模块生成三份 mock 后运行双后端测试。

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

本地接入时，把消费方和本仓库放在同一个 `moon.work` 的 `members` 中，再在消费方的 `moon.mod` 中写 `import { "dtzrttp/moon-mock@0.2.0" }`。独立消费方测试复现了该配置。生成器使用官方解析器，运行库本身无需导入解析器。 [MoonBit 工作区说明](https://docs.moonbitlang.com/en/latest/toolchain/moon/workspace.html)

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

| 完整使用场景 | 使用方式及预期结果 |
| --- | --- |
| 数据库事务回归 | 数据访问层开发者从 Driver 生成 mock，令指定 SQL 写入抛错，登记开启事务、写入、回滚的顺序并禁止提交。测试确认错误传播及回滚恰好一次。 |
| SDK 异步重试 | SDK 开发者为 Transport 登记同一路径首次失败、第二次挂起后成功，运行真实重试逻辑，检查次数、顺序和最终响应。 |
| 接口变更的 CI 检查 | 维护者提交生成文件，CI 使用相同输入执行 `--check`。接口改动后未更新 mock 会返回2，重新生成并更新业务预期后再运行测试。 |

下列命令在仓库根目录运行。

| 示例 | 测试的业务行为 | 复现 |
| --- | --- | --- |
| 事务 | 写入失败后回滚，成功时按顺序提交 | `moon test examples/transaction --target js --deny-warn` |
| 网络传输 | 暂时错误触发重试，异步回调挂起后返回，关闭连接可抛错 | `moon test examples/transport --target js --deny-warn` |
| 订单编排 | 扣款、库存预留、订单保存及失败补偿，异步通知失败标记待重试 | `moon test examples/order --target js --deny-warn` |
| 缓存回源 | 缓存命中/故障降级、TTL、Unicode 长度上限和可选写入失败策略 | `moon test examples/cache --target js --deny-warn` |

在两个真实项目的固定版本中也跑通了离线接入测试。Exa SDK 使用生成的传输层替身验证客户端如何处理 401。moondb 使用生成的 `Driver` 验证事务回滚和游标读取。 [测试结果与复现步骤](docs/adoption.md) · [查重记录](docs/dedup.md)

## 支持范围

生成器支持同包的 `Self` 接收者方法，覆盖位置参数、必填与可省略的标签参数、命名类型、泛型类型应用、`&Trait` 对象、可选类型、元组及函数类型。同步和异步方法可具有默认实现。方法与嵌套函数类型各自保留同步或异步语义以及抛错效果，支持具体或通用错误类型、异步默认错误和 `noraise`。签名中的类型需要能在同包测试中解析。支持从同包多份源码解析超 trait。循环、缺失或重复声明，以及继承链中不同 trait 声明的同名方法会报告源码位置。方法泛型、条件错误、`nocancel` 和跨包 trait 生成属于后续范围。

匹配器支持 `and_`、`or_`、`not_`、`project` 和 `one_of`。通过 `Capture::matcher` 可以记录成功选中的调用参数。控制器提供不可变计数快照及带版本的 JSON 报告。继承冲突会同时定位两个声明，继承深度上限为 128 层。完整生成、预期配置、异步生命周期与 CI 过程见 [使用指南](docs/usage.md)。

## 0.2.0 新增功能

以下功能构成 `0.2.0` 相对 `0.1.0` 的新增内容。`0.1.0` 的发行包保持不变；使用这些新 API 时，请安装 `0.2.0`。历史发行证据与本次版本校验记录见[发行记录](docs/release.md)。

- `matchers` 包新增字符串前后缀/子串、Unicode 码点长度、整数区间、Option/Result、二元组投影、数组逐项与无序一一匹配器。无序匹配最多处理128项；数组构造会复制匹配器列表。
- `Controller::with_history` 开启有界循环调用历史；未启用时不记录。历史只保留方法名、成功/拒绝、错误码及期望序号，不保存参数、返回值或错误详情。容量范围为1至65536，可清理、导出 JSON，并可通过同步/异步作用域辅助函数自动核对未满足的调用。
- 生成器新增结构化 trait 检查、预解析源码复用和批量生成 API。CLI 增加 `inspect <文件.mbt> [--json]` 与 `batch <清单.json> [--check]`。检查只解析语法，不等同于类型检查。批量清单版本为1，最多256项；单文件读入后最多4MiB，每次批处理缓存最多1024个不同源码、总量64MiB。`moonbitlang/x/fs@0.5.1` 的同步读取接口会先把文件完整读入再检查长度，因此4MiB限制不保证限制超大文件的峰值读入内存。输出限定为清单目录内的相对 `*_wbtest.mbt` 路径，并拒绝词法路径逃逸、保留文件名及手写文件覆盖；已有输出若与任一输入内容完全相同也会保守拒绝，以防止硬链接覆盖。该限制不是符号链接沙箱。
- 生成错误会在写入前统一报告且不改输出；操作系统写入失败时多文件批次不是事务，JSON报告会标出`written`、`failed`和`not_attempted`，使用者应按报告恢复。
- 新增订单补偿和缓存回源两组可运行场景，覆盖同步/异步预期、错误传播、调用历史、捕获、顺序、边界校验和清理失败。

清单示例：

```json
{
  "schema_version": 1,
  "jobs": [
    { "source": "service.mbt", "trait": "Service", "output": "mock_service_wbtest.mbt", "sources": ["base.mbt"] }
  ]
}
```

```sh
moon-mock inspect service.mbt --json
moon-mock batch mocks.json
moon-mock batch mocks.json --check
```

## 验证与许可

CI 检查格式、静态检查、生成文件是否过期、JS/native 测试和 CLI 构建。构建后执行 `node tools/cli-smoke.mjs js` 和 `node tools/cli-smoke.mjs native` 验收 CLI。`node tools/consumer-smoke.mjs js` 和 `node tools/consumer-smoke.mjs native` 验证另一个 MoonBit 模块从生成到运行的流程。项目采用 Apache-2.0。 [来源与依赖许可](NOTICE.md)

2026-11-22 验收复核中，JS/native 各通过52项项目测试和10项独立模块测试。CLI 新增路径别名及硬链接覆盖保护，Windows 实际执行23条验收命令。96种签名组合全部进入消费模块的实际编译验收。发行包解压后再次运行同组测试，native 另验证独立安装。固定种子的模型对照覆盖32000次调用。 [测试口径和边界](docs/testing.md)

六个真实接口和三个合成接口的 CLI 基准分两批记录396个墙钟样本，其中264个来自真实接口，并保存运行库变更前后的双后端微基准。两批结果分别统计，包含环境、提交、输入输出哈希及实际采样方法。 [发行前实测](docs/benchmarks/release-0.1.0.md) · [历史与微基准](docs/benchmarks/2026-11-22.md) · [复现方法](docs/benchmarks/README.md)

`0.1.0` 已发布到Mooncakes，并实际从公开注册表安装native CLI，在仅包含消费模块的新工作区中完成生成及双后端各10/10测试；`0.2.0` 的发行校验值和独立安装结果见[发行记录](docs/release.md)。 [最终验收逐项自查](docs/acceptance.md)

截至2026-11-23，本地 Windows 工具链运行 `moon check`、`moon test` 和 `moon build` 的 JS/native 目标；项目测试两目标均为210/210。CLI 兼容脚本各23条命令通过，批量与检查工作流分别执行29条命令通过；主分支新 API 消费方各1/1，兼容消费方及当前源码 ZIP 消费方各10/10。源码规模为84个 MoonBit `.mbt` 文件、9248行，其中生成 mock 836行，非生成 MoonBit 源码/测试/示例/基准共8412行；统计不含 `.mbti` 接口文件、Markdown 和 JS 自动化脚本。主分支 JS/native release 微基准原始输出和限制见[扩展基准报告](docs/benchmarks/main-expansion-2026-11-23.md)。 [测试口径和边界](docs/testing.md)

`0.1.0` 的发行包、注册表验证、双后端微基准和采用记录仍是旧版历史证据；本轮新增功能的公开包与注册表消费验证以 `0.2.0` 的发行记录为准。
