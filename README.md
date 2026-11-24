# baton

A Claude Code plugin for PRD-driven, serial development: Sonnet implements, Codex reviews every task in a resumable session, Opus advises at checkpoints, and the run ends as one commit in a pull request.

Claude Code 插件。正常开发需求按 PRD 驱动的串行流程完成：

1. `/baton:prd`：读代码收集仓库上下文，写 PRD，Codex 交叉验证，用户确认定稿。
2. `/baton:build`：拆 TASKS，逐条由 Sonnet 实现者写代码，Codex 只读审查（同一会话续审，最多 5 轮），Opus 顾问在 4 个节点把关；整次任务一个 commit，推送新分支并向基线发合并请求，跟到 CI 全绿。

正常开发需求 Claude 会自动走 build；一两行的小改、问答、纯文档配置改动不会触发。

## 依赖

- `codex` CLI（已登录）。Reviewer 默认 `gpt-6.2-astra` / high，可用 `BATON_REVIEW_MODEL`、`BATON_REVIEW_EFFORT` 覆盖。
- CNB 仓库需要 `cnb` CLI（`npm i -g @cnbcool/cnb-cli && cnb login`）；GitHub 仓库需要 `gh`。

## 文件

## 结构

| 路径 | 内容 |
|---|---|
| `skills/prd` | 需求调研、PRD 起稿、Codex 交叉验证、用户确认 |
| `skills/build` | 拆任务、逐条实现与审查、顾问把关、提交与合并请求 |
| `agents/implementer.md` | Sonnet 实现者，按说明实现单条任务，不碰 git |
| `agents/advisor.md` | Opus 只读顾问，在四个节点给判断 |
| `references/engineering.md` | 工程准则：第一性原理、优先成熟方案、不绕路、不做向后兼容、不过度设计、不过度捕获错误 |
| `references/prd-template.md` | PRD 模板 |
| `references/briefs.md` | TASKS 格式与各角色的说明模板 |
| `references/pull-request.md` | CNB / GitHub 合并请求与 CI 跟踪 |
| `scripts/start.sh` | 从最新基线切分支，建 `.baton/<branch>/` 工作目录 |
| `scripts/review.sh` | Codex 只读审查，首轮自动附上工程准则，续接同一会话，结构化结论 |

PRD、TASKS、审查记录放在仓库内 `.baton/<branch>/`，由 `.git/info/exclude` 排除，不进 PR。

## 安装

```bash
claude plugin marketplace add shiwenbin1617/baton
claude plugin install baton@baton
```

会话内也可以用 `/plugin marketplace add shiwenbin1617/baton` 和 `/plugin install baton@baton`。安装后执行 `/reload-plugins`。
