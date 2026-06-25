#!/usr/bin/env bash
# Сборка и запуск Swell (music-player)
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

PROJECT="music-player.xcodeproj"
SCHEME="music-player"
CONFIG="${1:-Debug}"
DERIVED_DATA="$(pwd)/build/DerivedData"

echo "▶ Сборка ($CONFIG)…"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA"

APP_PATH=$(find "$DERIVED_DATA" -name "music-player.app" -maxdepth 6 | head -1)

if [[ -z "$APP_PATH" ]]; then
  echo "❌ Не удалось найти собранный .app" >&2
  exit 1
fi

echo "✅ Готово: $APP_PATH"
echo "▶ Запуск…"
open "$APP_PATH"
