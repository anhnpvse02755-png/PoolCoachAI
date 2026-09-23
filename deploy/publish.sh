#!/usr/bin/env bash
# Build web rồi đẩy bundle lên nhánh deploy-easypanel mà Easypanel
# (project test-va, service poolcoachai) build từ đó.
#
#   FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat deploy/publish.sh
#
# Chỉ chạy từ một commit sạch: nhánh deploy ghi lại hash nguồn.
set -euo pipefail

FLUTTER="${FLUTTER:-flutter}"
root="$(git rev-parse --show-toplevel)"
cd "$root"

if [ -n "$(git status --porcelain)" ]; then
  echo "Cây làm việc còn thay đổi chưa commit — dừng." >&2
  exit 1
fi
src="$(git rev-parse --short HEAD)"

"$FLUTTER" build web --release

for f in sqlite3.wasm drift_worker.js; do
  [ -f "build/web/$f" ] || { echo "build/web/$f thiếu — DB sẽ vỡ trên web." >&2; exit 1; }
done

stage="$(mktemp -d)"
trap 'git worktree remove --force "$stage" 2>/dev/null || true' EXIT

git fetch origin deploy-easypanel 2>/dev/null || true
if git show-ref --verify --quiet refs/remotes/origin/deploy-easypanel; then
  git worktree add --detach "$stage" origin/deploy-easypanel
else
  git worktree add --detach "$stage"
  (cd "$stage" && git checkout --orphan deploy-easypanel-tmp)
fi

(
  cd "$stage"
  git rm -rqf --ignore-unmatch . >/dev/null
  rm -rf ./*
  cp "$root/deploy/Dockerfile" "$root/deploy/nginx.conf" .
  cp -r "$root/build/web" web
  git add -A
  git commit -qm "deploy: web build từ $src" || echo "Bundle không đổi."
  git push origin HEAD:refs/heads/deploy-easypanel
)
echo "Đã đẩy deploy-easypanel (nguồn $src)."
