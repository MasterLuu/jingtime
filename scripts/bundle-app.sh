#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN="$(swift build -c release --show-bin-path)/BeijingTime"
APP="build/北京时间.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/BeijingTime"
cp "Supporting/Info.plist" "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/BeijingTime"
codesign --force --sign - "$APP" >/dev/null
echo "$APP"
