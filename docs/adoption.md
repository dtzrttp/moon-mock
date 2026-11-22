# 生态接口适配记录

本地从固定提交读取真实工具的源码并执行生成器。完整原始文件和命令输出留在本地验证目录。

| 可复核接口 | 实际结果 | 首版影响 |
| --- | --- | --- |
| [Exa SDK 的 Transport](https://github.com/marianoguerra/exa-mb/blob/924f04f0f8aa62133b7da26f0146bf3c5de62633/transport.mbt#L40) | 2026-11-22。生成的 `GeneratedTransport` 与项目原有的 `MockTransport` 共存。真实 `Client.search` 用例在 JS 和 native 各 2/2 通过。 | 检查 401 到 API 错误的转换。成功用例捕获真实请求，验证 Unicode 查询、空结果和响应编号。 |
| [moondb 的 Driver、AsyncDriver 和 Stmt](https://github.com/moonbitstack/moondb/blob/12ad7f71837c65f629fc6e23d662ab16cffccb53/src/driver.mbt#L36) | 2026-11-22。三个原始 trait 分别生成实现，包含默认方法。JS 和 native 各 5/5 通过。 | 同步和异步真实事务回滚、真实数组游标读取、预处理语句的绑定执行与关闭、嵌套事务保存点回滚后外层提交。 |

从零建立固定接口的替身通常需要手写 `impl`、调用记录、错误注入和匹配逻辑。在仓库的事务与异步示例中，业务测试只配置预期，生成代码承担 trait 实现。事务、传输两个案例均由实际生成的源码编译运行。独立模块验证进一步确保运行库可以作为消费者的白盒测试依赖使用。

复现 Exa 检查时，在该 SDK 固定提交的本地副本中，按 README 给两个模块配置 `moon.work`，将本模块加入 Exa 现有的 `moon.mod` 导入块。Exa 白盒测试包还需导入 `moonbitlang/async` 及 `@mock_runtime`。将 [接入测试夹具](../tools/fixtures/exa-integration.mbt.txt) 作为 `moon_mock_integration_wbtest.mbt` 放进 Exa 根目录，并在该目录执行以下命令。原 `transport.mbt` 无需修改。

```sh
moon-mock generate transport.mbt Transport --mock-name GeneratedTransport --output generated_transport_wbtest.mbt
moon test . --target js --filter '*接入 Exa*'
moon test . --target native --filter '*接入 Exa*'
```

## 复现 moondb 接入

1. 检出 moondb 的 `12ad7f71837c65f629fc6e23d662ab16cffccb53`。在两个本地模块的共同父目录创建 `moon.work`，成员为 moondb 和 moon-mock 的目录。将 moondb 副本原有的 `moon.work` 改名，使本次检查只解析这两个模块。
2. 在 moondb 的 `moon.mod` 现有导入块加入 `"dtzrttp/moon-mock@0.1.0"`，在 `src/moon.pkg` 添加 `import { "dtzrttp/moon-mock/runtime" @mock_runtime, "moonbitlang/async" } for "wbtest"`。把 [测试夹具](../tools/fixtures/moondb-integration.mbt.txt) 复制为 `src/moon_mock_integration_wbtest.mbt`。
3. 在 moondb 根目录执行下面的命令。上游原始源码保持原样。五项测试无需数据库、驱动服务或凭据。

```sh
moon-mock generate src/driver.mbt Driver --mock-name GeneratedDriver --output src/generated_driver_wbtest.mbt
moon-mock generate src/async_driver.mbt AsyncDriver --mock-name GeneratedAsyncDriver --output src/generated_asyncdriver_wbtest.mbt
moon-mock generate src/stmt.mbt Stmt --mock-name GeneratedStmt --output src/generated_stmt_wbtest.mbt
moon test src --target js --filter '*接入 moondb*'
moon test src --target native --filter '*接入 moondb*'
```

moondb 验证使用 `moon 0.1.20261104` 和 `moonc v0.10.20+65efd5b93`，以编译上游的 `#derive`。验证接受本项目运行库两处旧式 `derive` 的弃用警告。Windows native 编译的上游 async C 文件还会报告 `EINVAL` 宏重定义警告。项目 CI 继续使用原有固定工具链，并以 `--deny-warn` 验证 MoonBit 代码。
