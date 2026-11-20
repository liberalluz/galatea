<!-- translation-of: CONTRIBUTING.md -->
# 贡献指南

简体中文 · [English](CONTRIBUTING.md)

## 开始之前

- 读 `AGENTS.md`。
- 一个改动 = 一个批次 = 一个 PR。
- 一个分支只装一个改动；一个 PR 只讲一个行为。

## 哪些规则会被检查

| 规则 | 谁检查 | 何时生效 |
|---|---|---|
| 提交正文写 `Batch: B<n>`（无批次写 `Batch: none`） | `batch.py commit lint` | `process/sdp.md` 有批次表时 |
| 写出的批次号在 SDP 里存在 | `batch.py commit lint` | 同上 |
| PR 正文有 `- Batch: B<n>`，或 `- Batch: none — <理由>` | `batch.py pr --create`、`tools/gate/gate.py`、`tools/ci/pr_gate.py` | 批次 PR 总是；CI 里每个 PR |
| PR 正文保留模板各节、不留占位符 | `batch.py body`、`batch.py pr --prepare` | 总是 |
| 提交标题符合配置的格式 | `batch.py commit lint` | 配置了 `commit` 块时 |
| 配置的检查通过 | `batch.py check` | 配置了检查时 |

本页其余内容是人与人之间的约定，破坏了没有脚本会失败，评审仍可以要求做到。

## 分支

```text
main                 长期存在，受保护
feat/<topic>         用户可见的功能
fix/<topic>          缺陷修复
process/<topic>      只动流程或工具
```

- 一个分支 = 一个改动。
- 合并后删除分支。

## 提交

```text
<type>(<scope>): <subject>
```

类型：`feat`、`fix`、`docs`、`test`、`refactor`、`chore`、`ci`。
范围：模块或区域。

- 标题用祈使句、要短。
- 正文讲为什么，不讲做了什么，并写明批次。
- 不放密钥，不放生成产物。

## Pull request

- 一个 PR = 一个行为。评审可以要求拆分；一个 PR 装了两个改动，没有脚本会失败。
- 填写 PR 模板，不留占位符。
- 有 issue 或记录就链接上。
- 必需检查必须全绿。
- 评审之后不要重写历史，除非被要求。

## 合并

- 默认 squash 合并。
- 作者不能自审。
- 不要直接推 `main`。
- 检查失败就修，不绕过。
- 豁免要记录，不能只口头同意。

## 发布

- 版本号写在声明的 manifest 里。
- 打 tag `vX.Y.Z`。
- 打 tag 前 `CHANGELOG.md` 要有对应版本。
- 内容包打 tag 用 `pack/<space>/vX.Y.Z`。
