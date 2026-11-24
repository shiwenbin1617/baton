---
name: build
description: 本技能是正常开发需求的默认流程。适用于用户要求实现新功能、修改已有行为、修 bug、跨文件重构或接入新接口，例如“加一个……功能”“把……改成……”“修一下……的问题”“实现这个需求”“implement / add / fix / refactor ……”。只要需求不是特别小就主动使用，不必等用户点名。流程：先走 baton:prd 得到已确认的 PRD，然后串行拆任务，Sonnet 实现者逐条写代码，Codex 逐条只读审查，Opus 顾问在四个节点把关，最后一个 commit 推到新分支，向基线发合并请求并跟到 CI 全绿。以下情况不使用：一两行的明确小改、纯问答或排查、只改文档或配置、用户明确要求直接改。
argument-hint: "[base=<基线分支>] <需求描述>"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/start.sh *), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/review.sh *)
---

# build

以主控身份把一个开发需求做到合并请求 CI 全绿：拆任务、派活、审查、验证、提交、发 PR。写代码交给实现者，审查交给 Codex，方向判断交给顾问，主控对最终结果负责。

需求：$ARGUMENTS

## 授权

用户已对正常开发需求给出长期授权。本次任务内可以：建分支、commit、push 到本次功能分支、改写本次功能分支（`--force-with-lease`）、创建合并请求。

以下仍需用户在对话里明确同意：合并、推送其他分支、部署、执行数据库迁移、任何数据操作。

## 原则

- **准则为准。** 代码怎么写、怎么审，以 `${CLAUDE_PLUGIN_ROOT}/references/engineering.md` 为准：第一性原理、优先成熟方案、不绕路、不做向后兼容、不过度设计、不过度捕获错误。开工前读一遍。
- **单线串行。** 一次只做一条，前一条通过才开始下一条。不并行实现，不开 worktree。
- **不问人。** PRD 确认后全程自动推进。查不到的事把假设写进 TASKS.md，按推荐方案继续。
- **不猜。** 接口和需求先查代码与文档，能复用就不新建。
- **不谎报。** 定位不到根因就补日志，报告信息不足，不说修好了。
- **一次提交。** 整次任务只在收尾时 commit 一次。过程中用暂存区标记已通过的条目。

## 角色

| 角色 | 由谁担任 | 职责与权限 |
|---|---|---|
| 主控 | 当前会话 | 拆任务、写说明、审 diff、跑检查、commit、发 PR。高风险条目亲自实现 |
| 实现者 | `baton:implementer`（Sonnet） | 按说明实现一条任务，跑检查。不能做任何 git 写操作 |
| Reviewer | `scripts/review.sh`（Codex，默认 `gpt-6.2-astra`，high，只读沙箱） | 每条审查，续接同一会话，默认最多 5 轮 |
| 顾问 | `baton:advisor`（Opus，只读） | 只在节点 a、b、c、d 给判断 |

高风险条目以 PRD 的“风险”节为准。环境变量 `BATON_REVIEW_MODEL`、`BATON_REVIEW_EFFORT` 可以换 Reviewer 的模型和推理档位。

## 资源

- `${CLAUDE_PLUGIN_ROOT}/references/engineering.md`：工程准则。
- `${CLAUDE_PLUGIN_ROOT}/references/briefs.md`：TASKS 格式，以及实现者、Reviewer、顾问的说明模板。
- `${CLAUDE_PLUGIN_ROOT}/references/pull-request.md`：CNB 和 GitHub 的 PR 命令、PR 正文模板、CI 跟踪规则。
- `${CLAUDE_PLUGIN_ROOT}/skills/prd/SKILL.md`：PRD 阶段。
- `${CLAUDE_PLUGIN_ROOT}/scripts/review.sh <workdir> <id> [max-rounds]`：退出码 0 通过，2 打回，3 达到上限。

---

## 阶段 0：PRD

**目标：** 拿到用户已确认的 PRD。

**动作：**
1. 找 `.baton/<branch>/PRD.md`。它不存在，或首行不是 `状态：已确认`，就读 `skills/prd/SKILL.md` 并完整执行，用户确认后回到这里。
2. 续跑时以已有的 PRD 和 TASKS.md 为准，从第一个未勾选的条目继续。

---

## 阶段 1：拆任务

**目标：** 一份有序、每条都能单独验证的任务清单。

**动作：**
1. 读工程准则和 PRD。
2. 按 PRD 顺序写 `.baton/<branch>/TASKS.md`，格式见 briefs。每条写清动作、完成标准，以及覆盖哪几条验收标准。
3. 排序：数据形状和类型先行，被依赖的先做，每条完成后仓库都处于可测试的状态。
4. 标出高风险条目。
5. 请顾问审拆分和方案（节点 a）。成立的意见改进 TASKS，不采纳的把理由写进 TASKS.md。

---

## 阶段 2：逐条执行

**目标：** 每一条都实现、自检、审查通过后，再进入下一条。

每条 T<n> 的动作：

1. **实现。**
   - 普通条目：按 briefs 模板写说明，派一个新的 `baton:implementer`。
   - 高风险条目：主控按工程准则亲自实现。
2. **自检。** 读 `git diff`，确认改动符合说明和准则。跑受影响的测试和检查。不通过就用 `SendMessage` 把问题交给同一个实现者，直到通过。实现者报告方案冲突时，主控核实后决定改方案还是改说明，必要时修订 PRD。
3. **审查。** 按 briefs 模板写 `.baton/<branch>/reviews/T<n>.prompt.md`，运行 `review.sh .baton/<branch> T<n>`。
4. **处理结论。**
   - 退出码 0：`git add -A`，在 TASKS.md 勾 `[x]`。
   - 退出码 2：逐条判断。成立的交给实现者修，主控自检后按复审模板改写 prompt，再跑同一命令。不成立的不改，理由写进复审 prompt 和 TASKS.md。同一条第 2 次被打回时，先请顾问诊断根因再修（节点 b）。
   - 退出码 3：标 `[!]`，在条目下写明遗留问题，`git add -A`，继续下一条。
5. **排查卡住。** 同一个 bug 排查两轮仍没有根因，请顾问决定下一步收集什么证据（节点 c）。

给顾问的说明按 briefs 模板写，要自包含。不采纳顾问意见时把理由写进 TASKS.md。

---

## 阶段 3：收尾

**目标：** 最终 diff 满足全部验收标准，干净地提交成一个 commit。

**动作：**
1. 跑 PRD 仓库上下文里规定的收尾审查。没有规定就跳过。修完后重跑受影响的检查。
2. 请顾问终审（节点 d），材料是 PRD 和全量 `git diff --cached`。不通过的项修完后再审。
3. 按仓库提交钩子的要求和 commit 惯例提交一次。钩子失败就修根因，不要用 `--no-verify` 跳过。

---

## 阶段 4：合并请求

**目标：** PR 已创建，CI 全绿。

**动作：** 按 `references/pull-request.md` 执行：推送功能分支、写 PR 正文、向基线创建合并请求、跟踪 CI 并修到全绿。不合并。

---

## 阶段 5：交付

**目标：** 让用户只看一条回复就能验收。

**动作：** 回复用户：
- 用户目标，一句话。
- 每个仓库的 PR 链接和 CI 状态。
- 验收标准核对表：每条标出通过或未通过，以及证据。
- 顾问终审结论。
- 所有 `[!]` 条目及遗留问题。
- 写进 TASKS.md 的假设，以及没采纳的审查和顾问意见。
