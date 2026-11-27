#!/usr/bin/env bash
# 退出码：0 通过，2 打回，3 达到轮次上限，其他为脚本或 Codex 故障
set -euo pipefail

usage="usage: review.sh <workdir> <task-id> [max-rounds]"
workdir="$(cd "${1:?$usage}" && pwd)"
task="${2:?$usage}"
max_rounds="${3:-5}"
here="$(cd "$(dirname "$0")" && pwd)"
schema="$here/verdict.schema.json"
standards="$here/../references/engineering.md"
model="${BATON_REVIEW_MODEL:-gpt-6.2-sol}"
effort="${BATON_REVIEW_EFFORT:-high}"

root="$(git -C "$workdir" rev-parse --show-toplevel)"
cd "$root"
dir="$workdir/reviews"
prompt="$dir/$task.prompt.md"
session_file="$dir/$task.session"
rounds_file="$dir/$task.rounds"

[[ -f "$prompt" ]] || { echo "缺少 $prompt" >&2; exit 1; }
round=$(( $(cat "$rounds_file" 2>/dev/null || echo 0) + 1 ))
(( round <= max_rounds )) || { echo "$task 已达 $max_rounds 轮上限" >&2; exit 3; }
out="$dir/$task.r$round.json"

# PRD 审查的对象在 .baton/ 里，不看代码 diff
if [[ "$task" != "PRD" ]]; then
  git add -N -A
  if git diff --quiet; then
    echo "$task 没有未暂存的改动，无可审查" >&2
    exit 1
  fi
fi

codex_args=(--json --output-schema "$schema" -o "$out" -m "$model" -c model_reasoning_effort="$effort")

# codex exec 在 stdin 未关闭时会一直等输入
if [[ -s "$session_file" ]]; then
  codex exec resume -c sandbox_mode='"read-only"' "${codex_args[@]}" \
    "$(cat "$session_file")" "$(cat "$prompt")" </dev/null >/dev/null
else
  events="$(mktemp)"
  trap 'rm -f "$events"' EXIT
  codex exec -s read-only "${codex_args[@]}" \
    "$(cat "$standards"; printf '\n\n---\n\n'; cat "$prompt")" </dev/null >"$events"
  thread="$(jq -rR 'fromjson? | select(.type == "thread.started") | .thread_id' "$events" | head -n1)"
  [[ -n "$thread" ]] || { echo "未取得 Codex 会话 ID，无法续审" >&2; exit 1; }
  printf '%s\n' "$thread" >"$session_file"
fi

jq -e 'has("pass") and has("blocking")' "$out" >/dev/null 2>&1 \
  || { echo "Codex 结论不是合法 JSON：$out" >&2; exit 1; }
echo "$round" >"$rounds_file"
cat "$out"

if jq -e '.pass == true and (.blocking | length == 0)' "$out" >/dev/null; then
  exit 0
elif (( round >= max_rounds )); then
  exit 3
else
  exit 2
fi
