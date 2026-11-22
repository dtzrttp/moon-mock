# 第三方来源

- 生成器依赖 MoonBit 官方 `moonbitlang/parser@0.4.7` 与 `moonbitlang/lexer@0.4.4`，模块许可证为 Apache-2.0。通过 Mooncakes 安装。 [parser](https://mooncakes.io/docs/moonbitlang/parser%400.4.7) · [源码与许可](https://github.com/moonbitlang/parser)
- CLI 使用 `moonbitlang/x@0.5.1` 读取、写入文件。异步测试使用 `moonbitlang/async@0.22.4`。两者均声明 Apache-2.0。 [x](https://mooncakes.io/docs/moonbitlang/x%400.5.1) · [async](https://mooncakes.io/docs/moonbitlang/async%400.22.4)
- GoMock 和 Mockall 是 API 设计参考。生成器、运行库和示例为本项目实现。 [GoMock](https://github.com/uber-go/mock) · [Mockall](https://github.com/asomers/mockall)
- moondb 用于本地接入测试。其固定版本使用 Apache-2.0，仓库仅收录本项目编写的接入用例。 [moondb 许可证](https://github.com/moonbitstack/moondb/blob/12ad7f71837c65f629fc6e23d662ab16cffccb53/LICENSE)
- Exa SDK 固定提交用于离线客户端接入及 CLI 生成基准，使用 Apache-2.0。基准脚本仅把公开上游源码下载到忽略的临时目录，输入提交、路径和 SHA-256 写入结果。 [Exa SDK 许可证](https://github.com/marianoguerra/exa-mb/blob/924f04f0f8aa62133b7da26f0146bf3c5de62633/LICENSE)
