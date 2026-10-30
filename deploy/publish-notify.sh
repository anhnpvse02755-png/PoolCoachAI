#!/usr/bin/env bash
# Biên dịch helper notify_plan cho linux-x64 rồi đẩy service notify lên nhánh
# deploy-notify mà Easypanel (project test-va, service notify) build từ đó.
# Helper chỉ được biên dịch ở máy dev hoặc CI, không bao giờ trên VPS.
#
#   FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat DART=/c/Users/anhnpv/flutter/bin/dart.bat deploy/publish-notify.sh
#
# Chỉ chạy từ một commit sạch: nhánh deploy ghi lại hash nguồn. Không in env.
set -euo pipefail

FLUTTER="${FLUTTER:-flutter}"
DART="${DART:-dart}"
root="$(git rev-parse --show-toplevel)"
cd "$root"

if [ -n "$(git status --porcelain)" ]; then
  echo "Cây làm việc còn thay đổi chưa commit — dừng." >&2
  exit 1
fi
src="$(git rev-parse --short HEAD)"

"$FLUTTER" pub get

# `dart compile exe` từ chối package có build hook (objective_c); `dart build cli`
# biên dịch chéo được và cho ra bundle/bin/notify_plan + bundle/lib/.
out="$(mktemp -d)"
stage="$(mktemp -d)"
trap 'git worktree remove --force "$stage" 2>/dev/null || true; rm -rf "$out"' EXIT
"$DART" build cli -t bin/notify_plan.dart -o "$out" --target-os linux --target-arch x64

bin="$out/bundle/bin/notify_plan"
[ -f "$bin" ] || { echo "Không thấy $bin sau khi biên dịch." >&2; exit 1; }
if [ "$(head -c 4 "$bin" | od -An -c | tr -d ' ')" != '177ELF' ]; then
  echo "bin/notify_plan không phải ELF — dừng." >&2
  exit 1
fi

git fetch origin deploy-notify 2>/dev/null || true
if git show-ref --verify --quiet refs/remotes/origin/deploy-notify; then
  git worktree add --detach "$stage" origin/deploy-notify
else
  git worktree add --detach "$stage"
  (cd "$stage" && git checkout --orphan deploy-notify-tmp)
fi

(
  cd "$stage"
  git rm -rqf --ignore-unmatch . >/dev/null
  find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  mkdir -p bin lib
  cp "$bin" bin/notify_plan
  if [ -d "$out/bundle/lib" ] && [ -n "$(ls -A "$out/bundle/lib")" ]; then
    cp -r "$out/bundle/lib/." lib/
  else
    : > lib/.gitkeep
  fi
  cp "$root/server/notify/package.json" "$root/server/notify/package-lock.json" "$root/server/notify/Dockerfile" .
  cp -r "$root/server/notify/src" src
  git add -A
  git add --chmod=+x bin/notify_plan
  git commit -qm "deploy: notify từ $src" || echo "Bundle không đổi."
  git push origin HEAD:refs/heads/deploy-notify
)
echo "Đã đẩy deploy-notify (nguồn $src)."
