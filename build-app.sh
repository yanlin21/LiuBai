#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h}"
OUTPUT_DIR="$ROOT_DIR/outputs"
APP_DIR="$OUTPUT_DIR/留白.app"
DERIVED_DATA="$ROOT_DIR/.build/xcode-release"
TEAM_ID="${LIUBAI_TEAM_ID:-}"

if [[ -z "$TEAM_ID" ]]; then
  echo "请先设置你的 Apple Developer Team ID："
  echo "  LIUBAI_TEAM_ID=XXXXXXXXXX ./build-app.sh"
  exit 1
fi

cd "$ROOT_DIR"
python3 "$ROOT_DIR/scripts/make_icon.py" "$ROOT_DIR/Assets/LiuBaiIcon.png" "$ROOT_DIR/Assets/LiuBai.icns"

xcodebuild \
  -project "$ROOT_DIR/LiuBai.xcodeproj" \
  -scheme LiuBai \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ENABLE_USER_SCRIPT_SANDBOXING=NO \
  OTHER_SWIFT_FLAGS=-disable-sandbox \
  build

rm -rf "$APP_DIR"
ditto "$DERIVED_DATA/Build/Products/Release/留白.app" "$APP_DIR"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_DIR"
echo "$APP_DIR"
