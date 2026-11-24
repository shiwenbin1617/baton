# 合并请求

按 `git remote get-url origin` 判断托管平台，`<owner/repo>` 取自该地址的路径部分，不带 `.git`。

## 命令

| 动作 | CNB（`cnb.cool`） | GitHub（`github.com`） |
|---|---|---|
| 创建 | `cnb pulls post-pull --repo <owner/repo> --base <base> --head <branch> --title "<标题>" --body-file <pr.md>` | `gh pr create --base <base> --head <branch> --title "<标题>" --body-file <pr.md>` |
| 查看 | `cnb pulls get-pull --repo <owner/repo> --number <N>` | `gh pr view <N>` |
| 查 CI | `cnb pulls list-pull-commit-statuses --repo <owner/repo> --number <N>` | `gh pr checks <N>` |
| 失败日志 | `cnb pulls get-ci-logs --sn <构建号>` | `gh run view <run-id> --log-failed` |
| 评论 | `cnb pulls list-pull-comments --repo <owner/repo> --number <N>` | `gh pr view <N> --comments` |

PR 链接：CNB 为 `https://cnb.cool/<owner/repo>/-/pulls/<N>`，GitHub 为 `https://github.com/<owner/repo>/pull/<N>`。

依赖：CNB 需要 `cnb` CLI 且已 `cnb login`；GitHub 需要 `gh` 且已 `gh auth login`。CLI 未登录时停下，请用户自己登录，不要代为输入凭据。

## PR 正文

写到 `.baton/<branch>/pr.md`：

```markdown
## Why

<用户目标，一两句话>

## 改了什么

- <按模块概括，不逐文件罗列>

## 怎么验证

- <跑过的测试和检查>
- <验收标准核对结果>

## 遗留

- <[!] 条目和未解决问题，没有写“无”>
```

标题沿用仓库的 commit 惯例。

## CI 跟踪

1. 创建后轮询 CI 状态，直到全部结束。
2. 失败时取日志，定位根因并修复。不要跳过检查、改阈值或禁用测试。
3. 修复后 `git commit --amend --no-edit`，再 `git push --force-with-lease origin <branch>`，PR 始终保持一个 commit。只改写本次的功能分支。
4. 全绿后停止。不合并，合并由用户执行。
5. 同一个失败修了两轮仍不过，按 build 的节点 c 问顾问。
