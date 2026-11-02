#!/bin/bash
# 离屏渲染 24 种落定特效，每个主题一张（或按指定时间点多张）。
# 用法：./render-fx.sh [输出目录] [时间点，逗号分隔]
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$ROOT/build/fx}"
TIMES="${2:-0.55}"
SDK="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
PLUGINS="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"

mkdir -p "$ROOT/build"
# 不含 RandomApp.swift（带 @main，与顶层代码冲突）
/usr/bin/xcrun swiftc \
  -sdk "$SDK" \
  -target arm64-apple-macos14.0 \
  -swift-version 5 \
  -plugin-path "$PLUGINS" \
  -o "$ROOT/build/FxRenderer" \
  "$ROOT/Random/ClassRoster.swift" \
  "$ROOT/Random/RosterFormat.swift" \
  "$ROOT/Random/Speech.swift" \
  "$ROOT/Random/Platform.swift" \
  "$ROOT/Random/GlassKit.swift" \
  "$ROOT/Random/Sound.swift" \
  "$ROOT/Random/Grouping.swift" \
  "$ROOT/Random/History.swift" \
  "$ROOT/Random/AppModel.swift" \
  "$ROOT/Random/DesignKit.swift" \
  "$ROOT/Tools/fxshots/main.swift"

"$ROOT/build/FxRenderer" "$OUT" "$TIMES"
