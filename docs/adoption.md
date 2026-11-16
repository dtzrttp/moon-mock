# 生态接口适配记录

本地从固定提交读取真实工具的源码并执行生成器。完整原始文件和命令输出留在本地验证目录。

| 可复核接口 | 实际结果 | 首版影响 |
| --- | --- | --- |
| [Exa SDK 的 Transport](https://github.com/marianoguerra/exa-mb/blob/924f04f0f8aa62133b7da26f0146bf3c5de62633/transport.mbt#L40) | 命令退出 0，从未改动的文件生成 `MockTransport`，含 `expect_send`、`respond_send`、`raise_send` 及异步方法实现 | 本次验证了真实源码的生成阶段。运行验证由本仓库的传输重试示例和独立消费方测试覆盖。 |
| [moondb 的 Driver](https://github.com/moonbitstack/moondb/blob/12ad7f71837c65f629fc6e23d662ab16cffccb53/src/driver.mbt#L36) | 命令退出 1，在 `query_stream` 的默认实现处报告 `unsupported_signature` | 此类用户可将更窄的事务依赖定义为本包 trait 再生成。默认方法支持是提高真实生态覆盖的下一步。 |

从零建立固定接口的替身通常需要手写 `impl`、调用记录、错误注入和匹配逻辑。在仓库的事务与异步示例中，业务测试只配置预期，生成代码承担 trait 实现。事务、传输两个案例均由实际生成的源码编译运行。独立模块验证进一步确保运行库可以作为消费者的白盒测试依赖使用。
