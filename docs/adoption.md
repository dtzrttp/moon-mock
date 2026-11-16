# 生态接口适配记录

本地从固定提交读取真实工具的源码并执行生成器。完整原始文件和命令输出留在本地验证目录。

| 可复核接口 | 实际结果 | 首版影响 |
| --- | --- | --- |
| [Exa SDK 的 Transport](https://github.com/marianoguerra/exa-mb/blob/924f04f0f8aa62133b7da26f0146bf3c5de62633/transport.mbt#L40) | 在固定提交内生成 `GeneratedTransport`，与项目原有的 `MockTransport` 共存。真实 `Client.search` 用例在 JS 上 1/1 通过 | 预期检查 POST 路径和一次调用。客户端把模拟的 401 转换为真实 API 错误，执行时无需 API 密钥或网络。 |
| [moondb 的 Driver](https://github.com/moonbitstack/moondb/blob/12ad7f71837c65f629fc6e23d662ab16cffccb53/src/driver.mbt#L36) | 命令退出 1，在 `query_stream` 的默认实现处报告 `unsupported_signature` | 此类用户可将更窄的事务依赖定义为本包 trait 再生成。默认方法支持是提高真实生态覆盖的下一步。 |

从零建立固定接口的替身通常需要手写 `impl`、调用记录、错误注入和匹配逻辑。在仓库的事务与异步示例中，业务测试只配置预期，生成代码承担 trait 实现。事务、传输两个案例均由实际生成的源码编译运行。独立模块验证进一步确保运行库可以作为消费者的白盒测试依赖使用。

复现 Exa 检查时，在该 SDK 固定提交的本地副本中，按 README 给两个模块配置 `moon.work`，将本模块加入 Exa 现有的 `moon.mod` 导入块。Exa 白盒测试包还需导入 `moonbitlang/async` 及 `@mock_runtime`。将 [接入测试夹具](../tools/fixtures/exa-integration.mbt.txt) 作为 `moon_mock_integration_wbtest.mbt` 放进 Exa 根目录，并在该目录执行以下命令。原 `transport.mbt` 无需修改。

```sh
moon-mock generate transport.mbt Transport --mock-name GeneratedTransport --output generated_transport_wbtest.mbt
moon test . --target js --filter '*接入 Exa*'
```
