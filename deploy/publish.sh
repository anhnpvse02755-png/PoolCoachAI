#!/usr/bin/env bash
# Build web rồi đẩy bundle lên nhánh deploy-easypanel mà Easypanel
# (project test-va, service poolcoachai) build từ đó.
#
#   FLUTTER=/c/Users/anhnpv/flutter/bin/flutter.bat DART=/c/Users/anhnpv/flutter/bin/dart.bat deploy/publish.sh
#
# Chỉ chạy từ một commit sạch: nhánh deploy ghi lại hash nguồn.
set -euo pipefail

: "${VAPID_PUBLIC_KEY:?Thiếu VAPID_PUBLIC_KEY (khoá công khai, đặt trong settings.local.json)}"

FLUTTER="${FLUTTER:-flutter}"
DART="${DART:-dart}"
root="$(git rev-parse --show-toplevel)"
cd "$root"

if [ -n "$(git status --porcelain)" ]; then
  echo "Cây làm việc còn thay đổi chưa commit — dừng." >&2
  exit 1
fi
src="$(git rev-parse --short HEAD)"

# *.g.dart bị git bỏ qua: bản checkout sạch không có, build sẽ hỏi.
"$FLUTTER" pub get
"$DART" run build_runner build --delete-conflicting-outputs

"$FLUTTER" build web --release --dart-define=VAPID_PUBLIC_KEY="$VAPID_PUBLIC_KEY"

for f in sqlite3.wasm drift_worker.js push/sw.js; do
  [ -f "build/web/$f" ] || { echo "build/web/$f thiếu — DB hoặc push sẽ vỡ trên web." >&2; exit 1; }
done

# Flutter không được đăng ký worker `/` của riêng nó (nó sẽ che worker push):
# bootstrap phải kết thúc bằng `_flutter.loader.load();` trần, không có
# serviceWorkerVersion.
boot=build/web/flutter_bootstrap.js
[ -f "$boot" ] || { echo "$boot thiếu." >&2; exit 1; }
[ "$(grep -v '^[[:space:]]*$' "$boot" | tail -n 1 | tr -d '\r')" = "_flutter.loader.load();" ] \
  || { echo "$boot không kết thúc bằng _flutter.loader.load(); — worker Flutter có thể được đăng ký." >&2; exit 1; }
[ "$(grep -c 'serviceWorkerVersion: *[0-9"]' "$boot" || true)" = "0" ] \
  || { echo "$boot còn serviceWorkerVersion — worker Flutter sẽ được đăng ký." >&2; exit 1; }

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
