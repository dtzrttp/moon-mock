# 从 trait 到 CI 的完整用法

在同包源码中定义依赖接口，例如数据库、传输层或任务队列。构建本仓库的 CLI，并在业务项目的白盒测试包导入运行库。

```moonbit
import {
  "dtzrttp/moon-mock/runtime" @mock_runtime,
} for "wbtest"
```

## 生成和检查

以仓库内消费方夹具为例，在夹具目录运行下列命令。安装或构建 CLI 的方法见 README。

```sh
moon-mock generate service.mbt Service --source branch_traits.mbt --source base_traits.mbt --output mock_service_wbtest.mbt
moon-mock generate service.mbt Service --source branch_traits.mbt --source base_traits.mbt --check mock_service_wbtest.mbt
moon test . --target js --deny-warn
```

同包父 trait 用 `--source` 显式提供。缺少文件、父 trait 不存在、声明重复或继承循环都会给出诊断。辅助文件顺序不会影响继承遍历顺序。方法冲突会报告两个声明的位置。同名方法分属两个祖先时，当前生成器会要求使用者调整接口。继承深度上限为 128 层，以控制递归栈消耗。

生成文件作为普通源码提交。CI 中执行同一条生成命令并使用 `--check`，若源接口变更导致输出过期，CLI 返回 2。更新生成文件后重新运行使用方测试。

## trait 检查与批量生成

`inspect` 可输出 trait、父 trait、方法位置、异步标记和参数数目。它只运行源码解析器，不执行完整类型检查，也不保证该 trait 一定可生成。

```sh
moon-mock inspect service.mbt
moon-mock inspect service.mbt --json
```

`batch` 接受 schema 版本1的 JSON 清单。`sources` 为可选同包辅助源码数组，`mock_name` 为可选生成类型名。路径相对于清单文件所在目录；输入可使用绝对路径，输出只允许目录内相对 `*_wbtest.mbt` 路径。

```json
{
  "schema_version": 1,
  "jobs": [
    {
      "source": "service.mbt",
      "trait": "Service",
      "output": "mock_service_wbtest.mbt",
      "sources": ["base.mbt"]
    }
  ]
}
```

```sh
moon-mock batch mocks.json
moon-mock batch mocks.json --check
```

批次最多256项、每个源码读入后最多4MiB、最多缓存1024份不同源码且总量不超过64MiB。当前 `moonbitlang/x/fs@0.5.1` 同步 API 会先完整读入再检查大小，因此此限制不约束超大输入的峰值分配；不要把 CLI 当作处理不可信大文件的隔离沙箱。生成前会完成清单、输入、输出路径和已有文件预检；存在生成错误时保留逐项 JSON 诊断且不会写入输出。已有输出若和任意输入内容完全相同，会保守拒绝，避免不同路径的硬链接别名。检查模式报告 `current` 或 `out_of_date`。

文件写入错误可能发生在批次中途，批量写入不是多文件事务。此时命令仍会输出 JSON，已完成项标为 `written`，失败项标为 `failed`，未执行项标为 `not_attempted`；使用者需根据该报告决定是否重试或恢复文件。

## 组合匹配和捕获

```moonbit
test "记录读取的对象" {
  let capture : @mock_runtime.Capture[Int32] = @mock_runtime.Capture::new()
  @mock_runtime.with_mock(controller => {
    let mock = MockService::new(controller)
    let allowed = @mock_runtime.matching("正数", (id : Int32) => id > 0)
      .and_(@mock_runtime.one_of([7, 42]))
    mock.expect_lookup(capture.matcher(allowed), "book", times=2)
    assert_eq(Reader::lookup(mock, id=42), "book")
    assert_eq(Reader::lookup(mock, id=7), "book")
    assert_eq(capture.values(), [42, 7])
  })
}
```

`and_` 和 `or_` 按从左向右的短路规则判断。两个分支都匹配时，`or_` 只对左分支执行捕获。`not_` 成功时没有被肯定选中的分支，因此不会捕获其内部参数。`project("数量", args => args.1)` 可以先提取元组或领域对象字段再匹配。

谓词和投影函数应为无副作用的函数，执行次数可随组合结构和候选预期而变化。参数捕获发生在次数和顺序检查成功后、行为回调开始前。回调之后抛错或取消仍计为一次调用。超次数、顺序不符和参数不符的调用不会产生捕获记录。

`values()` 返回数组副本。参数自身包含数组或可变对象时，元素仍遵循 MoonBit 的引用语义。若需要保存调用时的完整内容，可通过投影或响应回调复制所需字段。

## 通用匹配器

使用方可导入 `dtzrttp/moon-mock/matchers`，组合文本、整数、Option/Result、元组和数组匹配器：

```moonbit
let label = @matchers.starts_with("订单-")
let amount = @matchers.int_range(1, 5000).unwrap()
let tags = @matchers.every_element(@matchers.contains_text("有效"))
assert_true(label.matches("订单-42"))
assert_true(amount.matches(250))
assert_true(tags.matches(["有效会员", "有效库存"]))
```

文本长度按 Unicode 标量值计数。区间构造会校验上下界；无序数组通过一一分配处理重复值，超过128项返回 `too_many_elements`。由 `and_`、数组投影等组合嵌套的捕获会在任何用户通知回调前冻结，确保回调改写数组或重入 mock 时记录的仍是最初匹配值。

## 可选调用历史

`Controller::with_history(capacity)` 开启1至65536条容量的循环记录；默认创建的 controller 不保存调用历史。`with_mock_history` 和 `with_mock_history_async` 可在测试体结束时像普通作用域一样核对缺失调用。

历史只存序号、方法名、成功/拒绝状态、稳定错误码及匹配到的预期索引，不存调用参数、回调返回值或诊断文字。缓冲区写满后覆盖最早事件，`history_dropped()` 报告丢弃数；快照返回独立数组，`clear_history()` 清空事件但保留序号。该能力不是完整审计日志，也不保证跨系统线程安全。

## 统计和结构化报告

`Controller::snapshot()` 按登记顺序返回 `ExpectationStatus`，包含方法名、匹配说明、上下限、已调用次数和是否达到下限。旧快照保持原有计数。`report()` 返回可直接序列化的 JSON，例如下面的一次成功读取。

```json
{
  "schema_version": 1,
  "closed": false,
  "expectations": [
    {
      "method_name": "Reader.lookup",
      "matcher": "任意参数",
      "minimum": 1,
      "maximum": 1,
      "seen": 1,
      "satisfied": true
    }
  ]
}
```

报告适合测试结束后打印或作为 CI 附件。匹配说明由使用者提供，`equal_to` 和 `one_of` 会把期望值写入说明，因此写日志时应选取适合公开的测试数据。JSON 使用 MoonBit 标准序列化处理引号、换行和 Unicode。

## 登记失败与异步生命周期

手写高级适配器可以调用 `Method::try_expect` 获取 `Result`。非法次数、已关闭作用域、跨控制器共享顺序组时返回稳定错误码，登记前的控制器和顺序组保持原状。生成接口继续采用严格的 `expect_*`，错误配置会立即终止当前测试。

`CallCount::try_between` 和 `try_at_least` 可用于先校验来自测试配置的区间。同一个顺序组只属于一个控制器，跨测试应创建新的顺序组。

`with_mock_async` 支持同一个 MoonBit 异步运行时内的协作任务。预期选择、顺序前进和计数均发生在用户回调挂起前。作用域内应等待任务结束，测试体错误与取消按原样传播。作用域结束后，逃逸的 mock 会报告 `scope_closed`。跨操作系统线程共享控制器尚未提供同步保证。

## 发行包验证

0.2.0在AST转译阶段限制类型嵌套最多64层，嵌套类型参数、元组成员、可选类型、函数参数/返回/错误类型沿各自路径累计层数。超限返回带文件、行列的`resource_limit`。继承深度仍最多128层。这不是对官方解析器的完全资源隔离；公开0.1.0不包含这些后续优化。

```sh
moon package --list
node tools/package-smoke.mjs js
node tools/package-smoke.mjs native
```

脚本检查 ZIP 的源码、许可证及路径，解压到新的临时目录，再从发行包构建 CLI 并在全新消费模块执行十项接入测试。native 流程还通过 `moon install ./cmd/moon-mock --bin <临时目录>` 验证安装产物可执行。`node tools/registry-smoke.mjs 0.2.0` 进一步从公开注册表下载运行库与 CLI，在没有本地模块替换的全新工作区验证生成和双后端测试。
