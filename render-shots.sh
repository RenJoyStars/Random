#!/bin/bash
# 离屏渲染截图：不依赖显示器，直接把界面渲染成 PNG。
# 用法：./render-shots.sh [输出目录]（默认 build/shots）
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$ROOT/build/shots}"
SDK="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
PLUGINS="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"

mkdir -p "$ROOT/build"
# 注意：不含 RandomApp.swift —— 它带 @main，与这里的顶层代码冲突
/usr/bin/xcrun swiftc \
  -sdk "$SDK" \
  -target arm64-apple-macos14.0 \
  -swift-version 5 \
  -plugin-path "$PLUGINS" \
  -o "$ROOT/build/ShotRenderer" \
  "$ROOT/Random/ClassRoster.swift" \
  "$ROOT/Random/RosterFormat.swift" \
  "$ROOT/Random/Speech.swift" \
  "$ROOT/Random/Platform.swift" \
  "$ROOT/Random/Sound.swift" \
  "$ROOT/Random/Grouping.swift" \
  "$ROOT/Random/History.swift" \
  "$ROOT/Random/AppModel.swift" \
  "$ROOT/Random/DesignKit.swift" \
  "$ROOT/Random/RootView.swift" \
  "$ROOT/Random/ClassroomViews.swift" \
  "$ROOT/Random/ToolViews.swift" \
  "$ROOT/Random/ToolFlourish.swift" \
  "$ROOT/Random/HistoryView.swift" \
  "$ROOT/Random/SettingsView.swift" \
  "$ROOT/Tools/shots/main.swift"

"$ROOT/build/ShotRenderer" "$OUT"
