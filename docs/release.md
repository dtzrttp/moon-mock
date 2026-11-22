# 0.1.0 公开发行记录

2026-11-22由用户指定账号dtzrttp发布，模块为[dtzrttp/moon-mock@0.1.0](https://mooncakes.io/docs/dtzrttp/moon-mock%400.1.0)。发布源码提交为 `a1da289e7e197c10c66dcbc0b24684c40e76c543`；核心代码与已通过双后端[CI的20210c0](https://github.com/dtzrttp/moon-mock/actions/runs/44995678974)相同，后续提交只增加发行前基准证据。

本地ZIP的SHA-256和公开注册表返回的checksum完全一致：

```text
8f1233a3beeb8248adf1341f6fe81821c18e1c6371cb2ee37549284b6f71755d
```

实际执行 `moon whoami` 确认dtzrttp，`moon publish --dry-run`完成本地检查、打包解压检查并返回202 Accepted；随后 `moon publish`返回200 OK。公开元数据确认版本未撤回，license为Apache-2.0，依赖与moon.mod一致。包内保留LICENSE与NOTICE，不含构建缓存或凭证。

## 从公开注册表安装验收

实际运行 `node tools/registry-smoke.mjs 0.1.0`。脚本创建全新工作区，只有consumer一个成员，没有本地moon-mock替换。以下步骤全部成功：

1. `moon view dtzrttp/moon-mock@0.1.0 --json`获取公开版本和校验值。
2. `moon install dtzrttp/moon-mock/cmd/moon-mock@0.1.0 --bin <临时目录>`从发行版构建安装native CLI，并执行帮助命令。
3. 使用安装后的CLI分别生成及检查Catalog、Service、SignatureMatrix三个mock。
4. `moon tree`确认依赖解析到 `dtzrttp/moon-mock@0.1.0`，并非工作区本地路径。
5. `moon test . --target js --deny-warn`和native对应命令分别10/10通过；96种签名进入实际编译。

[安装元数据、依赖树和测试输出](releases/0.1.0-install.json)保留实际结果，只把本机项目绝对路径替换为“项目目录”，其余编译警告和结果保留。固定工具链为MoonBit0.10.18；Windows native上游async的EINVAL宏重定义提示仍存在，未将其误报为MoonBit检查失败。

首次安装native CLI会编译官方解析器等依赖，在本机耗时数分钟，需要C工具链和网络。运行库和生成物已经过JS/native验证，其他后端未验证。后续main分支的验收文档不改变已发布0.1.0内容，公开包校验值以本页记录为准。
