# moon-mock 查重与选题评估

复查日期为 2026-11-16（北京时间）。本轮未发现明确重合的公开 MoonBit 工具。比较标准是能否读取现有 MoonBit trait 并生成类型安全的实现，且通用地校验调用参数、次数和顺序。

## 可复核记录

- Mooncakes 使用实际安装的 `moon search`。记录包括 `moon-mock`、`mock`、`mockgen`、`mockall`、`gomock`、`mocking`、`test double`、`trait mock`、`stub` 和 `spy`。默认文本查询都成功。JSON 查询 `moon search --limit 50 --json` 返回 `moon-mock` 17 项、`trait mock` 47 项和 `mock` 50 项，最后一项触及查询上限。`--limit 200` 返回 HTTP 422，属于查询失败。原始记录在本地 `docs/evidence/moon-*.txt`、`docs/evidence/moon-limit50-*.json`。
- GitHub 按仓库名、描述、README 和 `.mbt` 源码查询。`moon-mock in:name` 返回 18 个仓库。`moonbit mocking in:name,description,readme` 重新分页后返回 147 项。`"mock" "trait" extension:mbt` 返回 66 个文件。`"mockgen" extension:mbt` 返回 2 个文件，均是针对 AI SDK 的现成测试模型及其测试。针对 `mock generator`、`trait mock` 的 Markdown README 短语查询均为零。搜索命令、返回状态、结果列表、候选仓库元数据与源码核查记录保存在本地 `docs/evidence/`。第一轮宽查询的 PowerShell JSON 分页解析失败已用第二轮结果替代。搜索结论受公开索引和查询范围限制。

## 相近项目

| 项目 | 已核对的范围 |
| --- | --- |
| [MoonContract](https://github.com/Han-Wentao/mooncontract) | 0.1.1 的 README、测试说明和公开接口显示其从 OpenAPI 生成 HTTP 响应。`MockEngine.respond` 的输入是 HTTP 请求。 |
| [smock](https://github.com/hirunefu/smock) | README 和仓库范围是 HTTP/HTTPS/SSE 模拟服务。 |
| [moonctl](https://github.com/moonbitstack/moonctl) | README 和源码树显示其从服务 DSL、Proto 或数据库描述生成脚手架和服务代码。 |
| [aya-orm 的 FakeDb](https://github.com/Allianaab2m/aya-orm/tree/main/src/driver/fake) | 源码实现固定的 `Executor`、`Driver`，可记录 SQL、模拟失败。测试覆盖查询、事务提交和回滚。它是拟用来评估手写替身成本的真实案例。 |
| [moondb](https://github.com/moonbitstack/moondb) 与 [mttp](https://github.com/gaato/mttp) | 前者提供固定数据库驱动替身。后者的测试包围绕 HTTP 传输，提供调用预期、故障注入等实际相邻能力。 |
| [moonsim](https://github.com/zlhahaha/moonsim) 与 [quickcheck_statemachine](https://github.com/moonbit-community/quickcheck_statemachine) | 分别提供确定性事件模拟和基于模型的状态机测试。后者的 `mock` 是生成命令时的符号响应函数。 |
| [GoMock](https://github.com/uber-go/mock) 与 [Mockall](https://github.com/asomers/mockall) | 功能对标，分别生成 Go 接口和 Rust trait 的 mock。可参考调用预期 API，不引入其实现代码。 |

## 价值判断

建议做。现有可查证的用法包括手写 HTTP transport mock、数据库 fake driver 和可插拔的 AgentBackend。这些项目已经证明开发者需要替换依赖、制造错误并检查互动。拟交付的增量是同一个类型化生成器和预期运行库可以跨项目复用，并能随 trait 改动重新生成，减少测试替身维护。

适用对象是用 trait 表达依赖边界、确实需要断言交互的测试。外部复用和维护收益应由实际样例验证。首版用两个业务类型不同的适配案例展示同一生成器，记录生成前后的手写代码和失败诊断，避免仅以合成 demo 证明通用性。
