---
name: build
description: 默认开发流程。新功能、行为变更、bug 修复、跨文件重构等正常开发需求一律使用：先写 PRD 并由用户确认，然后串行拆任务，Sonnet 实现、Codex 逐条审查、Opus 顾问把关，整次任务一个 commit，从基线开新分支推送并发合并请求。以下情况不用：一两行的明确小改、纯问答或排查、只改文档或配置、用户明确要求直接改。
argument-hint: "[base=<基线分支>] <需求描述>"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/start.sh *), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/review.sh *)
---

# build

用户对正常开发需求的长期授权：本次任务内可以建分支、commit、push 到本次功能分支、改写本次功能分支（含 `--force-with-lease`）、创建合并请求。合并、推送其他分支、部署、执行迁移、数据操作仍需用户明确同意。

## 入口

`.baton/<branch>/PRD.md` 首行没有 `状态：已确认` 时，先读 `${CLAUDE_PLUGIN_ROOT}/skills/prd/SKILL.md` 并照做，用户确认后回到这里。续跑时以已有的 PRD 和 TASKS 为准。

## 角色

| 角色 | 由谁担任 | 权限 |
|---|---|---|
| 主控（你） | 当前会话 | 拆任务、写任务说明、审 diff、验证、commit、PR。高风险条目亲自实现 |
| 实现者 | `baton:implementer` 子代理（Sonnet） | 只改代码和跑检查，禁止 git 写操作 |
| Reviewer | `${CLAUDE_PLUGIN_ROOT}/scripts/review.sh`（Codex，默认 `gpt-6.2-astra`，high，只读沙箱） | 只读，每条最多 5 轮 |
| 顾问 | `baton:advisor` 子代理（Opus） | 只读，只给判断，不写代码、不打回、不扩范围 |

Reviewer 可用环境变量 `BATON_REVIEW_MODEL`、`BATON_REVIEW_EFFORT` 调整模型，第三个参数是轮次上限。高风险范围以 PRD 的“风险”节为准。

## 硬规则

- 单线串行。一次只做一条，不并行实现，不开 worktree。
- 不猜。接口和需求先查代码与文档，能复用不新建。查不到就把假设写进 TASKS.md 条目下，取推荐方案继续，不向用户提问。
- 错误必须暴露。不写吞错的兜底，修根因。定位不到就补日志，报告信息不足，不谎称修好。
- 只做 PRD 要求的。不加抽象层、扩展点、新旧接口并存、dead code。这条同样约束 Reviewer 和顾问的意见。
- 整次任务只在收尾时 commit 一次。过程中用暂存区标记已通过的条目。

## 1. 拆任务

按 PRD 顺序写 `.baton/<branch>/TASKS.md`。每条一行 `- [ ] T<n> <动作和完成标准>`，必要时在下面挂假设。续跑以它为准，不跳项。

交给顾问审拆分和顺序（节点 a）。

## 2. 逐条执行

每条 T<n>：

1. **实现。** 普通条目派一个新的实现者。任务说明自包含：用户目标一句话、条目原文、PRD 路径、要动的文件和数据形状、PRD 仓库上下文里的规范入口和检查命令。高风险条目主控自己写。
2. **自检。** 主控读 `git diff`，跑受影响的测试和检查。没过就用 `SendMessage` 让同一个实现者修。
3. **审查。** 把 Reviewer 说明写到 `.baton/<branch>/reviews/T<n>.prompt.md`，执行 `${CLAUDE_PLUGIN_ROOT}/scripts/review.sh .baton/<branch> T<n>`。首轮说明包含：
   - 条目原文和 PRD 路径。
   - 本条改动是 `git diff`（未暂存部分）。`git diff --cached` 是已通过的条目，仅作上下文。
   - 读完整 diff，只报能给出触发路径的遗漏和 bug。不以“建议增强”打回，不提监控、重试、配置开关、额外抽象。
   复审时把 prompt 文件改写为“已修复哪些、哪些不成立及理由，复审同一范围”，再跑同一命令。脚本会续接同一个 Codex 会话。
4. **处理结论。** 退出码 0：`git add -A`，在 TASKS.md 勾 `[x]`。退出码 2：逐条判断，真问题交给实现者修后再审，不成立的把理由写进 TASKS.md 条目下；第 2 次被打回时先问顾问根因再修（节点 b）。退出码 3：标 `[!]`，在条目下写明未解决问题，`git add -A`，继续下一条。
5. 排查 bug 两轮仍找不到根因，问顾问（节点 c）。

每次问顾问，说明自包含：目标、相关 PRD 段落、diff 范围或报错、已排除的假设。不采纳时把理由写进 TASKS.md。

## 3. 收尾

1. 跑 PRD 仓库上下文里规定的收尾审查，修完重跑受影响的检查。
2. 顾问终审（节点 d）：对照验收标准看 `git diff --cached` 全量。
3. 按仓库提交钩子的要求和 commit 惯例，一次 commit。

## 4. 合并请求

按 `git remote get-url origin` 选平台，`<owner/repo>` 取自该地址：

| 平台 | 创建 | 查 CI | 取失败日志 |
|---|---|---|---|
| `cnb.cool` | `cnb pulls post-pull --repo <owner/repo> --base <base> --head <branch> --title "<标题>" --body-file <pr.md>` | `cnb pulls list-pull-commit-statuses --repo <owner/repo> --number <N>` | `cnb pulls get-ci-logs --sn <构建号>` |
| `github.com` | `gh pr create --base <base> --head <branch> --title "<标题>" --body-file <pr.md>` | `gh pr checks <N>` | `gh run view <run-id> --log-failed` |

1. `git push origin <branch>`。
2. PR 正文写到 `.baton/<branch>/pr.md`：以 `## Why` 开头写用户目标，再写改了什么、怎么验证、`[!]` 条目。
3. 向基线分支创建合并请求。
4. 跟踪 CI。失败就取日志修根因，`git commit --amend --no-edit` 后 `git push --force-with-lease origin <branch>`，保持一个 commit。
5. CI 全绿即停，不合并。

## 交付

回复用户：

- 用户目标一句话。
- 每个仓库的 PR 链接。
- 验收标准逐条核对表。
- 顾问终审结论。
- 所有 `[!]` 条目及未解决问题。
- 写进 TASKS.md 的假设。
