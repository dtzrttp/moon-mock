# 核心能力扩展计划

2026-11-23，基线9aef1b5，基线Git跟踪MoonBit源码3238行。用户要求扩大到8000行。本轮新增可复用功能及对应验证，没有用空白、依赖源码或重复测试补足规模。

## 设计选择

比较三条路线：只扩充测试不能改善日常使用；直接支持跨包类型和方法泛型需要更完整的名称解析及专门设计；本轮选择完善通用匹配、可选调用观测、trait检查与批量生成，并提供完整业务示例。既有严格预期语义、生成物配置和已发布0.1.0保持兼容；新增能力纳入0.2.0。

## 公共约束

- 仅dtzrttp提交，无共同作者；Apache-2.0，自建实现及夹具，不新增外部依赖。
- 官方parser0.4.7，MoonBit0.10.18，JS/native为验收目标；其他后端不作承诺。
- 保留确定性、可定位错误和受控资源；新能力先测试再实现，记录实际命令。
- 不根据源码行数评价正确性；统计区分核心、测试、业务接口、基准、生成物。

## 子任务与验收

- [x] matchers新包：实现字符串、整数区间、Option/Result、元组及数组匹配；针对空值、重复值、Unicode、边界、短路和可变数组选择通知编写测试。只依赖runtime。
- [x] runtime：增加默认关闭的有界调用历史，不保存原始参数；记录成功/拒绝、方法、稳定错误码与顺序。覆盖容量、快照、清理、同步异步作用域和固定种子模型。
- [x] generator：增加trait检查、结构化诊断、批量验证/生成、准备态源码复用；结果维持输入顺序，检查重复输出。覆盖混合错误、辅助源码、顺序和资源边界。
- [x] CLI：增加`inspect` JSON诊断和`batch` manifest；测试包括失败不写、硬链接别名防护、部分写入状态、路径和文件名限制、缺失文件、UTF-8和文件上限。保留原有`generate`。同步读取先整文件载入再检查4MiB限制，不能用作超大不可信输入的内存隔离；多文件写入也非事务。
- [x] 增加订单补偿/缓存回源两个离线示例，生成mock另计；增加独立main消费方测试，JS/native各实际生成并运行1/1。
- [x] 更新中文README、使用说明和变更记录。`moon fmt`、JS/native `moon check/test/build`、CLI、兼容消费方、主分支新API消费方和当前源码 ZIP 消费均已在本机执行；远程 CI 的JS/native矩阵均通过。代码审查发现的别名及写入报告问题已修正；4MiB 限制因同步文件 API 只能在完整读入后检查，作为已记录限制保留。

## 规模和本地验收结果

统计 Git 跟踪与非忽略未跟踪的 MoonBit `.mbt` 文件：84个文件、9248行；识别8个以生成标记开头的 mock 文件，共836行。非生成部分8412行，分为实现6908行、测试和基准1504行；不含 `.mbti`、文档和JS工具。代码规模不是正确性证据。

- 编译器：`moonc v0.10.18+6c83a7f62`；目标为JS和Windows native。
- `moon test --target js/native --deny-warn`：每目标210/210。
- `moon check`、`moon build`：JS/native均成功。
- `node tools/workflow-smoke.mjs js/native`：每目标29条命令均通过。
- `node tools/main-consumer-smoke.mjs js/native`：每目标独立消费方1/1。
- `node tools/consumer-smoke.mjs js/native`：每目标10/10；`node tools/package-smoke.mjs js/native`：当前源码 ZIP 解压消费方每目标10/10。
- `node tools/cli-smoke.mjs js/native`：每目标23条命令通过。
- `moon bench runtime matchers generator --target js/native --release --deny-warn`均实际运行，9/9成功；环境、原始输出、代表数据及波动限制见`docs/benchmarks/main-expansion-2026-11-23.md`。未据此宣称普遍性能提升。

## 分工与集成

matchers仅修改新matchers目录；history仅修改runtime；inspection/batch仅修改generator；主任务负责CLI、示例、集成脚本和文档。各任务只读其他目录接口，提交由主任务统一进行。注册表0.1.0记录作为历史保留，新能力的0.2.0发布结果见[发行记录](release.md)。
