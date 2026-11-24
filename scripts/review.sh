#!/usr/bin/env bash
# 退出码：0 通过，2 打回，3 达到轮次上限仍未通过
set -euo pipefail

workdir="${1:?usage: review.sh <workdir> <task-id> [max-rounds]}"
task="${2:?usage: review.sh <workdir> <task-id> [max-rounds]}"
max_rounds="${3:-5}"
schema="$(cd "$(dirname "$0")" && pwd)/verdict.schema.json"
root="$(git rev-parse --show-toplevel)"
workdir="$(cd "$workdir" && pwd)"
cd "$root"
dir="$workdir/reviews"
prompt="$dir/$task.prompt.md"
session_file="$dir/$task.session"
rounds_file="$dir/$task.rounds"

[[ -f "$prompt" ]] || { echo "缺少 $prompt" >&2; exit 1; }
round=$(( $(cat "$rounds_file" 2>/dev/null || echo 0) + 1 ))
out="$dir/$task.r$round.json"

# codex exec 在 stdin 未关闭时会一直等输入
if [[ -f "$session_file" ]]; then
  codex exec resume -c sandbox_mode='"read-only"' \
    --json --output-schema "$schema" -o "$out" \
    "$(cat "$session_file")" "$(cat "$prompt")" </dev/null >/dev/null
else
  codex exec -s read-only -m "${BATON_REVIEW_MODEL:-gpt-6.2-astra}" -c model_reasoning_effort="${BATON_REVIEW_EFFORT:-high}" \
    --json --output-schema "$schema" -o "$out" "$(cat "$prompt")" </dev/null \
    | sed -nE 's/.*"type":"thread.started","thread_id":"([^"]+)".*/\1/p' > "$session_file"
fi

echo "$round" > "$rounds_file"
cat "$out"

if grep -q '"pass":[[:space:]]*true' "$out"; then
  exit 0
elif (( round >= max_rounds )); then
  exit 3
else
  exit 2
fi
