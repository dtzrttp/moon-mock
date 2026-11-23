# 基准复现

在项目根目录构建两个后端的 release CLI，随后运行基准。普通运行只使用三个合成接口，`--real` 另外读取六个固定提交的公开接口，下载的文件缓存在忽略的 `_build/benchmark-inputs`。有缓存后可离线重跑。数据来源与许可证在 `tools/fixtures/benchmark-upstream.json`。

```sh
moon build --target js --release --deny-warn
moon build --target native --release --deny-warn
node tools/benchmark.mjs --real --samples=11
moon bench runtime generator --target js --release --deny-warn --no-parallelize
moon bench runtime generator --target native --release --deny-warn --no-parallelize
```

CLI 数据保存到 `_build/benchmark-results.json`。脚本每项先预热两次，再分别启动指定数量的新进程，记录原始墙钟样本、中位数、p95、输入和输出哈希及环境。时间包含进程启动、读取、解析、生成、格式化和输出。11 个样本的 p95 按最近秩法等于最大值。

运行库和生成器的微基准通过标准 `moon bench` 执行。它们复用运行中的进程，测量方法选择、失败报告、完整顺序调用和解析生成格式化。输出保留均值、标准差、范围及每组重复次数。

计数器在 Int32 上界饱和，基准即使重复极多次也可继续运行。成功调用的微基准使用无上限计数。顺序场景每轮重新登记32条预期并完整调用，包含登记和分配成本。

共享机器、编译器、垃圾回收、进程启动和电源管理均会影响结果。每份报告适用于注明的环境和输入。当前数据用于定位本项目的开销及比较本次优化前后行为。

主分支新增加的匹配器、调用历史和预解析/批量生成微基准，原始输出和环境记录见[2026-11-23扩展基准](main-expansion-2026-11-23.md)。该基准只描述本地这一台Windows机器，不作为跨设备的性能保证。
