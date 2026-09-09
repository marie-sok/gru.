#!/bin/zsh
set -euo pipefail

BRANCH="security/p0-recovery-metadata"
REMOTE_MATCH="marie-sok/gru."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$ROOT/swiftui/GRU/gru..xcodeproj"
SCHEME="gru"
BUNDLE_ID="sok.com.gru"
DERIVED="$ROOT/.derivedData-p0-device"
STAMP="P0-$(date +%Y%m%d-%H%M%S)"
# CFBundleVersion-safe: first component <=4 digits, second/third <=2.
BUILD_NUMBER="$(date +%y%m).$(date +%d).$(date +%M)"

print_section() {
  echo ""
  echo "========== $1 =========="
}

print_section "GRU FRESH PHYSICAL IPHONE"
echo "ROOT: $ROOT"

if [[ ! -d "$ROOT/.git" ]]; then
  echo "❌ Not a git checkout: $ROOT"
  exit 1
fi

REMOTE_URL="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
if [[ "$REMOTE_URL" != *"$REMOTE_MATCH"* ]]; then
  echo "❌ Wrong repository: $REMOTE_URL"
  exit 1
fi

print_section "BACKUP LOCAL CHANGES"
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
  git -C "$ROOT" stash push -u -m "auto-backup-before-fresh-iphone-$STAMP" >/dev/null
  echo "✅ Local changes saved to git stash"
else
  echo "✅ Working tree already clean"
fi

print_section "FORCE EXACT P0 SOURCE"
git -C "$ROOT" fetch origin "$BRANCH"
git -C "$ROOT" checkout "$BRANCH"
git -C "$ROOT" reset --hard "origin/$BRANCH"
git -C "$ROOT" clean -fd

LOCAL_SHA="$(git -C "$ROOT" rev-parse HEAD)"
REMOTE_SHA="$(git -C "$ROOT" rev-parse "origin/$BRANCH")"
if [[ "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
  echo "❌ Local and remote branch do not match"
  exit 1
fi

echo "✅ HEAD: $(git -C "$ROOT" rev-parse --short HEAD)"

print_section "REMOVE STALE GRU CHECKOUTS"
CANONICAL_ROOT="$(cd "$ROOT" && pwd -P)"
TRASH="$HOME/.Trash"
mkdir -p "$TRASH"

PROJECT_CANDIDATES=("${(@f)$(find "$HOME" -maxdepth 7 \
  \( -path "$HOME/Library" -o -path "$HOME/.Trash" \) -prune -o \
  -type d -name 'gru..xcodeproj' -print 2>/dev/null)}")

seen_roots=()
for proj in "${PROJECT_CANDIDATES[@]:-}"; do
  [[ -d "$proj" ]] || continue
  [[ "$proj" == "$PROJECT" ]] && continue

  candidate_root="$(git -C "$(dirname "$proj")" rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$candidate_root" ]] || continue
  candidate_root="$(cd "$candidate_root" 2>/dev/null && pwd -P || true)"
  [[ -n "$candidate_root" ]] || continue
  [[ "$candidate_root" == "$CANONICAL_ROOT" ]] && continue

  duplicate=0
  for seen in "${seen_roots[@]:-}"; do
    [[ "$seen" == "$candidate_root" ]] && duplicate=1
  done
  [[ $duplicate -eq 1 ]] && continue
  seen_roots+=("$candidate_root")

  candidate_remote="$(git -C "$candidate_root" remote get-url origin 2>/dev/null || true)"
  [[ "$candidate_remote" == *"$REMOTE_MATCH"* ]] || continue

  target="$TRASH/GRU-stale-$(date +%Y%m%d-%H%M%S)-${candidate_root:t}"
  echo "🗑 Moving stale clone to Trash: $candidate_root"
  mv "$candidate_root" "$target"
done

echo "✅ Stale GRU clones removed from active workspace"

print_section "CLEAR XCODE CACHE"
killall Xcode 2>/dev/null || true
rm -rf "$HOME/Library/Developer/Xcode/DerivedData/gru-"* 2>/dev/null || true
rm -rf "$HOME/Library/Developer/Xcode/DerivedData/GRU-"* 2>/dev/null || true
rm -rf "$DERIVED"
echo "✅ Xcode/DerivedData cache cleared"

print_section "PATCH CURRENT MAC LAN IP"
MAC_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
if [[ -z "$MAC_IP" ]]; then
  echo "❌ Could not detect Mac LAN IP"
  exit 1
fi

API_FILE="$ROOT/swiftui/GRU/gru./Services/APIClient.swift"
python3 - "$API_FILE" "$MAC_IP" <<'PY'
import re
import sys
path, ip = sys.argv[1], sys.argv[2]
text = open(path, "r", encoding="utf-8").read()
new = re.sub(
    r'private static let physicalDeviceHost = "[^"]+"',
    f'private static let physicalDeviceHost = "{ip}"',
    text,
)
if new == text and f'private static let physicalDeviceHost = "{ip}"' not in text:
    raise SystemExit("physicalDeviceHost was not found")
open(path, "w", encoding="utf-8").write(new)
print(f"✅ physicalDeviceHost = {ip}")
PY

print_section "CHECK LOCAL BACKEND"
READY="$(curl --max-time 5 -s "http://$MAC_IP:8081/ready" || true)"
echo "$READY"
if [[ "$READY" != *'"status":"ok"'* ]] || [[ "$READY" != *'"database":"ok"'* ]]; then
  echo "❌ Local backend/Mongo is not ready on $MAC_IP:8081"
  exit 1
fi

echo "✅ Backend + Mongo ready"

print_section "FIND PHYSICAL IPHONE"
DEVICE_LINE="$(xcrun xctrace list devices 2>/dev/null | awk '
  /^== Devices ==/ { in_devices=1; next }
  /^== Simulators ==/ { in_devices=0 }
  in_devices && /iPhone/ { print; exit }
')"

DEVICE_ID="$(echo "$DEVICE_LINE" | sed -E 's/.*\(([0-9A-Fa-f-]{20,})\)$/\1/')"
if [[ -z "$DEVICE_LINE" || "$DEVICE_ID" == "$DEVICE_LINE" || -z "$DEVICE_ID" ]]; then
  echo "❌ No connected physical iPhone detected"
  echo "Connect/unlock the iPhone, trust this Mac, enable Developer Mode and rerun."
  exit 1
fi

echo "✅ $DEVICE_LINE"
echo "DEVICE_ID: $DEVICE_ID"

print_section "CLEAN BUILD FROM EXACT CHECKOUT"
cd "$ROOT"
SOURCE_SHORT="$(git rev-parse --short HEAD)"
BUILD_STAMP="$STAMP-$SOURCE_SHORT"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  INFOPLIST_KEY_CFBundleDisplayName="gru. P0 FRESH" \
  INFOPLIST_KEY_GRUBuildStamp="$BUILD_STAMP" \
  clean build

APP="$DERIVED/Build/Products/Debug-iphoneos/gru.app"
if [[ ! -d "$APP" ]]; then
  echo "❌ Built app not found: $APP"
  exit 1
fi

print_section "VERIFY BUILT BINARY"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :GRUBuildStamp' "$APP/Info.plist" 2>/dev/null || echo "Build stamp: $BUILD_STAMP"

echo "SOURCE: $SOURCE_SHORT"
echo "APP: $APP"

print_section "FORCE INSTALL TO IPHONE"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
echo "✅ Fresh binary installed"

print_section "LAUNCH EXACT BUNDLE"
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID" || true

print_section "DONE"
echo "✅ Installed physical-device build: gru. P0 FRESH"
echo "✅ Source: $SOURCE_SHORT"
echo "✅ Build: $BUILD_NUMBER"
echo "✅ Stamp: $BUILD_STAMP"
echo ""
echo "The iPhone icon must now say 'gru. P0 FRESH'. If it still says only 'gru.', the fresh install did not replace the old binary."
