# 仓库结构与开源项目自查

复核日期：2026-11-24（北京时间）。本报告依据 [osc2026-guide 自查技能](https://github.com/Milky2018/osc2026-guide)复核项目结构、README、许可证、提交身份与历史、远程默认分支、MoonBit 源码规模和可复现验证。该技能面向 OSC 2026 与八月黑客松；本报告只采用用户指定的通用仓库检查维度，不把它当作本项目十一月赛事的官方规则，也不代表组委会验收结论。

## 结论

仓库结构清楚，README 可从安装走到示例和限制说明，Apache-2.0 与发行清单一致，32 条既有提交全部使用指定账号 `dtzrttp`，GitHub 默认分支为 `main`，且本地基线与远程分支同步。当前 MoonBit 主实现、测试、基准和生成样例的源码统计已重新核实。

本轮自查修正了两项文档问题：README 缺少明确的项目结构及版本状态说明；源码统计把生成 mock 混入测试，并错误拆分非生成代码类别。旧的 2026-11-22 验收文档仍作为当时快照保存在[历史记录](acceptance-2026-11-22.md)，不再充当当前状态说明。

## 仓库与发布状态

| 项目 | 复核结果 |
| --- | --- |
| 公开仓库 | [`dtzrttp/moon-mock`](https://github.com/dtzrttp/moon-mock)，GitHub 元数据标记为 public |
| GitHub 默认分支 | `main`；由 GitHub 仓库元数据确认 |
| 本地基线 | `e501e113969e0725771d42c30b1ba43381cff2fc`；本轮开始检查时 `main` 与 `origin/main` 相同 |
| 历史提交 | 基线包含32条提交，时间从2026-11-16至2026-11-24；每条提交的 author 和 committer 均为 `dtzrttp <313799694+dtzrttp@users.noreply.github.com>`，未发现共同作者署名 |
| 当前公开发行 | Mooncakes `dtzrttp/moon-mock@0.2.0`；Git 标签 [`v0.2.0`](https://github.com/dtzrttp/moon-mock/tree/v0.2.0) 指向[源码提交](https://github.com/dtzrttp/moon-mock/commit/378d0e10f2d1bcd19faa8321ca34cf779fda933d) |
| 工具链 | `moon 0.1.20261028`，`moonc v0.10.18+6c83a7f62`；版本由本机实际执行 `moon version --all` 得到 |
| 已验证后端 | JS、Windows native 与 Ubuntu CI 的 JS/native；macOS、Wasm/WASI 等未单独验证 |

`0.2.0` 的注册表校验值、依赖树和独立安装消费记录见[发行记录](release.md)及[安装证据](releases/0.2.0-install.json)。发行包对应上述标签源码提交；主分支后续文档变化不改变已发布包内容。

## 结构检查

| 路径 | 职责与检查结果 |
| --- | --- |
| `generator/` | 读取 MoonBit 官方语法树，分析 trait、继承及诊断，并生成普通 mock 源码 |
| `runtime/` | 管理调用预期、次数、顺序、参数匹配、可选调用历史和结构化诊断 |
| `matchers/` | 提供值、组合、区间、变体、元组投影、数组及无序匹配器 |
| `cmd/moon-mock/` | 提供 `generate`、`inspect` 和 `batch` CLI |
| `examples/` | 展示事务回滚、异步传输重试、订单补偿和缓存回源 |
| `tools/` | 执行仓库静态检查、CLI/消费方/发行包验证及基准编排；脚本不替代 MoonBit 核心实现 |
| `docs/` | 收录使用说明、版本决策、测试口径、发行记录、采用和基准证据 |
| `.github/workflows/ci.yml` | 固定工具链，对 JS/native 检查格式、构建、测试、CLI 和独立消费流程 |

根目录的 `moon.mod` 固定模块名 `dtzrttp/moon-mock`、版本 `0.2.0`、仓库地址和 `Apache-2.0`；依赖版本明确固定。仓库静态检查脚本还会检查文件布局、文档本地链接、缓存排除、提交身份、许可证字段和常见凭证模式。

## README 与使用说明

本轮在 README 加入模块结构、0.2.0 发布状态、发行源码 SHA 和后端验证边界；补充可直接到达 LICENSE 与 NOTICE 的链接，并以表格说明源码规模和统计方法。README 已包含：

- 安装 CLI 与运行库、最小 mock 预期示例，以及 `generate`、`inspect`、`batch` 的用法；
- 数据库事务、异步 SDK 重试和 CI 生成文件检查三个完整场景，另有四组可运行业务示例；
- 生成器支持的签名范围、资源限制、失败行为和暂不支持能力；
- 公开版本与当前主分支的区别、双后端验证范围、真实项目接入和发行证据链接；
- 历史基准的复现入口、结果波动限制、许可证与第三方来源说明。

更详细的参数和边界见[使用指南](usage.md)、[测试口径](testing.md)和[发行记录](release.md)。

## 许可证与来源

根目录包含完整 Apache License 2.0 文本，`moon.mod` 声明同一 SPDX 标识。NOTICE 说明项目版权、MoonBit parser/lexer、`moonbitlang/x`、async、传递依赖、标准库以及用于设计参考的 GoMock/Mockall，并列出真实 SDK 接入样例的固定上游提交与许可证。已发布包的注册表元数据报告 `Apache-2.0`，发行 ZIP 保留 LICENSE 和 NOTICE。该检查确认文件和记录相符，不构成对所有依赖未来变更的自动许可监控。

## MoonBit 源码规模

以下数字以本轮开始检查时的 Git 基线为准。统计输入为 `git ls-files '*.mbt'`，只计 Git 跟踪文件；逐文件按 LF 换行计数，末行若无换行符仍计一行。空行和注释均计入。分类互斥：先按首行生成标记识别生成 mock，再识别夹具、基准、测试，其余列为实现与应用示例。

| 类别 | 文件数 | 行数 | 识别规则 |
| --- | ---: | ---: | --- |
| 实现与应用示例 | 28 | 3,356 | 生成器、运行库、匹配器、CLI 和手写示例 |
| 测试 | 38 | 4,646 | `*_test.mbt` 与 `*_wbtest.mbt`，不含有生成标记的 mock |
| 基准 | 5 | 245 | `*_bench_test.mbt` |
| 解析器输入夹具 | 5 | 165 | `tools/fixtures/` 中非测试后缀的 `.mbt` 源输入 |
| 生成 mock 示例 | 8 | 836 | 首行包含 `由 moon-mock 生成`，单独统计，不视为手写实现 |
| **总计** | **84** | **9,248** | 以上类别相加 |

非生成 MoonBit 源码共8,412行。`.mbti`、Markdown、JavaScript 工具、未跟踪文件和构建产物不计入。统计包括测试与空白注释，因此不能把9,248行描述成手写产品实现规模，也不能用行数替代测试质量或实际功能。

## 实际本地复核

本轮在仓库基线实际运行了以下命令：

| 命令 | 结果 |
| --- | --- |
| `moon version --all` | `moon 0.1.20261028`、`moonc v0.10.18+6c83a7f62` |
| `moon fmt --check` | 成功，`Finished. moon: no work to do` |
| `moon check --target js --deny-warn` | 成功 |
| `moon check --target native --deny-warn` | 成功 |
| `moon test --target js --deny-warn` | 210/210 通过，0 失败 |
| `moon test --target native --deny-warn` | 210/210 通过，0 失败 |
| `moon build --target js --deny-warn` | 成功，生成 CLI JS 构建产物 |
| `moon build --target native --deny-warn` | 成功，生成 CLI native 构建产物 |
| `node tools/repository-check.mjs` | 通过，检查147个已跟踪文件和63个本地文档链接 |

CLI 批处理、独立消费方和发行 ZIP 的扩展验收结果沿用[测试记录](testing.md)及[0.2.0公开安装证据](releases/0.2.0-install.json)，不把本轮未重跑的项目写成新执行结果。GitHub Actions 的状态以对应链接的远程运行页面为准。

## 范围与剩余事项

自查未发现仓库身份、默认分支、许可证声明或本轮本地 MoonBit 检查方面的阻断项。以下事项仍需如实披露：

- 生成器暂不支持跨包 trait 类型解析、方法泛型、条件错误及 `nocancel`；具体边界见 README 和使用指南。
- JS 与 native 有验证证据；macOS 和其他后端尚未完成独立验证。
- 测试包含固定种子模型对照、签名组合、损坏输入变更和多后端消费流程；这不等于覆盖率引导 fuzzing 或独立安全审计。
- 基准是指定机器、提交和输入下的观测值，不承诺跨机器性能结论。
- 本文是工程自查记录，不预测或保证组委会最终验收结果。
