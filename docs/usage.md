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

报告适合测试结束后打印或作为 CI 附件。匹配说明由使用者提供，`equal_to` 会把期望值写入说明，因此写日志时应选取适合公开的测试数据。JSON 使用 MoonBit 标准序列化处理引号、换行和 Unicode。

## 登记失败与异步生命周期

手写高级适配器可以调用 `Method::try_expect` 获取 `Result`。非法次数、已关闭作用域、跨控制器共享顺序组时返回稳定错误码，登记前的控制器和顺序组保持原状。生成接口继续采用严格的 `expect_*`，错误配置会立即终止当前测试。

`CallCount::try_between` 和 `try_at_least` 可用于先校验来自测试配置的区间。同一个顺序组只属于一个控制器，跨测试应创建新的顺序组。

`with_mock_async` 支持同一个 MoonBit 异步运行时内的协作任务。预期选择、顺序前进和计数均发生在用户回调挂起前。作用域内应等待任务结束，测试体错误与取消按原样传播。作用域结束后，逃逸的 mock 会报告 `scope_closed`。跨操作系统线程共享控制器尚未提供同步保证。

## 发行包验证

```sh
moon package --list
node tools/package-smoke.mjs js
node tools/package-smoke.mjs native
```

脚本检查 ZIP 的源码、许可证及路径，解压到新的临时目录，再从发行包构建 CLI 并在全新消费模块执行九项接入测试。该流程使用工作区解析本地发行包，公开注册表的下载与发布另行记录。
