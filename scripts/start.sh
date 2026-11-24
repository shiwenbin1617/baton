#!/usr/bin/env bash
set -euo pipefail

branch="${1:?usage: start.sh <branch> [base]}"
root="$(git rev-parse --show-toplevel)"
cd "$root"
workdir="$root/.baton/$branch"

# 续跑：已在该分支且工作目录存在，沿用原来的基线
if [[ "$(git branch --show-current)" == "$branch" && -f "$workdir/base" ]]; then
  echo "base=$(cat "$workdir/base")"
  echo "workdir=$workdir"
  exit 0
fi

if git show-ref --verify --quiet "refs/heads/$branch"; then
  echo "分支 $branch 已存在。续跑请先切到该分支；新需求请换一个分支名" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "工作区有未提交改动，先处理再开工" >&2
  exit 1
fi

git fetch origin
base="${2:-}"
if [[ -z "$base" ]]; then
  if git show-ref --verify --quiet refs/remotes/origin/dev; then
    base=dev
  else
    base="$(git ls-remote --symref origin HEAD | sed -nE 's|^ref: refs/heads/([^[:space:]]+)[[:space:]]+HEAD$|\1|p')"
  fi
fi
[[ -n "$base" ]] || { echo "无法确定基线分支，请显式传入" >&2; exit 1; }

git checkout --no-track -b "$branch" "origin/$base"

exclude="$(git rev-parse --git-path info/exclude)"
grep -qxF '.baton/' "$exclude" 2>/dev/null || echo '.baton/' >>"$exclude"

mkdir -p "$workdir/reviews"
printf '%s\n' "$base" >"$workdir/base"
echo "base=$base"
echo "workdir=$workdir"
