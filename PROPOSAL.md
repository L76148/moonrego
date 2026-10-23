# moonrego 项目申报书

## 基本信息

- 项目名称：MoonRego：MoonBit 的 Rego（OPA）策略语言实现
- 参赛者：L76148
- 联系方式：2237501538@qq.com
- GitHub 仓库链接：https://github.com/L76148/moonrego
- 项目方向：新生态项目建设（语言与开发工具 / 云原生策略基础设施）
- 是否为移植项目：否，原创实现；语言语义参考 Open Policy Agent
- 开源许可证：Apache-2.0

## 项目简介

Rego 是 Open Policy Agent 的策略语言，Kubernetes 准入控制、Terraform/Conftest 合规检查、
微服务鉴权都在用它。MoonBit 已有 Cedar（`jaredzhou/mooncedar`）和 CEL
（`aloyscc/moon_cel`），但检索 `rego`、`opa policy` 均为零命中；需要在 MoonBit 里求值
现有 Rego 策略的服务没有任何原生手段。

本项目用纯 MoonBit 实现 Rego 的词法、语法、求值与 CLI：手写 lexer 与 Pratt parser，
带虚拟文档、partial set/object 与 undefined 语义的求值器，JSON data/input 桥接，
以及和 `opa eval` 对应查询的 `moonrego eval`。

## 项目价值与生态定位

痛点具体：策略是横切关注点，多数团队已经有 Rego 资产；如果 MoonBit 服务、WASM 过滤器
或 CLI 工具不能直接求值这些策略，就只能把策略翻译成另一门语言，或者把决策外包给一个
Go 进程。前者会语义漂移，后者把部署复杂度抬回去。

生态位：mooncakes 上 `rego` 与 `opa policy` 零命中；Cedar 与 CEL 是不同语言、不同语法，
不能替代。这里补的是"策略语言运行时"这一层，属于附录一推荐的"语言解释器/运行时"方向，
而不是单一游戏的规则库。

优势：零第三方依赖的纯 MoonBit 实现，可编译到 wasm，能嵌进 MoonBit 服务；错误带行列号；
求值器按查询记忆化，规则按包路径索引。

## 三个预期使用场景

1. Kubernetes 准入与 CI 合规：把现有 Rego 策略放进 wasm 过滤器或 CI 命令，对 JSON 输入
   求值 `data.example.allow`、`data.example.violations`。
2. 服务内鉴权：MoonBit 微服务把请求上下文作为 `input`，直接调用求值器做 ABAC/RBAC 判定，
   不必再起一个 OPA sidecar。
3. 策略测试与迁移：在 MoonBit 测试里批量跑 Rego 用例，对照 `opa eval` 的输出做差分，
   迁移或审计策略时不需要 Go 工具链。

## 核心功能范围

- 词法与语法：package/import、完整规则与 partial set/object、`default`、`else`、
  函数规则、`some`、`every`、`not`、推导式（数组/对象/集合）、引用与下标；
- 求值器：data/input 文档、虚拟文档、规则迭代、partial set/object、undefined 语义；
- 内置函数：比较、算术、字符串、数组、对象、集合、类型判断与 JSON 辅助；
- CLI：`eval`、`check`、`parse`；
- 公开 OPA 用例派生的 conformance corpus 与单元测试。

## 交付范围与工程边界

首版交付上面列出的核心能力，并把"不做什么"写清楚：不做 bundle、decision log、
partial evaluation、OPA REST server，也不做需要外部 I/O 的内置函数。边界理由：这些
属于 OPA 的部署与运维层，不是语言运行时；把语言本身做对、做可验证，才有复用价值。

## 实现路径与技术理解

词法手写，token 带行列与源码偏移；语法用手写 Pratt parser，因为 Rego 的表达式优先级
层次多，还要区分 term 与 expr。值模型包含 set 与 object，索引键必须可比较。求值按
"表达式到生成器"组织：`some`、推导式、规则迭代共用同一套生成器，undefined 通过
"无解"而不是异常传播。规则按 `package.path` 建索引，单次查询内记忆化，避免重复求值。
正确性用两层判据：单元测试覆盖语法与内置函数；conformance corpus 用公开 OPA 用例做
输入/输出差分。

## 预期验收产物

- `moon add L76148/moonrego` 可用的库；
- 可运行命令：`moon run cmd/moonrego -- eval|check|parse`；
- 在 wasm 与 wasm-gc 上通过的测试，覆盖词法、语法、求值与内置函数；
- README、接口文件、CI、Apache-2.0 许可证与 NOTICE；
- 发布到 mooncakes.io。

## 当前进展与验收证据

- 已完成：词法与语法（含推导式）、AST、值模型与 JSON 桥接、求值器核心（完整/partial 规则、
  default/else、变量绑定、some/every/not/with input、算术与集合运算）；
- 82 个测试在默认后端、`wasm` 与 `wasm-gc` 上全部通过；`moon check --deny-warn` 与
  `moon fmt --check` 通过；
- 下一增量：内置函数库、`eval` 命令与 conformance corpus；
- 提交按"一个功能一个提交"推进，每个提交对应一个可验证的能力。

## 原创性与参考说明

本项目为原创 MoonBit 实现，非移植，未复制 OPA 的 Go 代码。语言语义参考 Open Policy
Agent（https://github.com/open-policy-agent/opa，Apache-2.0），测试语料来自公开用例，
来源与许可证记录在 `NOTICE.md`。许可证为 Apache-2.0。