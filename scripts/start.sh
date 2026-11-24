#!/usr/bin/env bash
set -euo pipefail

branch="${1:?usage: start.sh <branch> [base]}"
root="$(git rev-parse --show-toplevel)"
cd "$root"

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
    base="$(git remote show origin | sed -n 's/.*HEAD branch: //p')"
  fi
fi

git checkout -b "$branch" "origin/$base"
git branch --unset-upstream

exclude="$(git rev-parse --git-path info/exclude)"
grep -qxF '.baton/' "$exclude" 2>/dev/null || echo '.baton/' >> "$exclude"

mkdir -p ".baton/$branch/reviews"
echo "base=$base"
echo "workdir=$root/.baton/$branch"
