#!/bin/bash
# 无头逻辑自测：不启动界面，只验证名单、随机、牌堆、猜拳、多人点名、播报文案与音效开关。
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
SDK="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"

# 护栏：自测绝不能改动用户真实导入的名单。
# （真实教训：曾有一条「远端名单下发」的测试写到默认路径，把老师 18 个班的名单覆盖了。）
# 这里在测试前后各取一次哈希，只要变了就判定失败。
REAL_ROSTER="$HOME/Library/Application Support/cn.renqiaoyi.random/Imported/active.randomroster"
ROSTER_BEFORE="$(shasum -a 256 "$REAL_ROSTER" 2>/dev/null | awk '{print $1}')"
PLUGINS="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"

mkdir -p "$ROOT/build"
/usr/bin/xcrun swiftc \
  -sdk "$SDK" \
  -target arm64-apple-macos14.0 \
  -swift-version 5 \
  -plugin-path "$PLUGINS" \
  -o "$ROOT/build/LogicTests" \
  "$ROOT/Random/ClassRoster.swift" \
  "$ROOT/Random/RosterFormat.swift" \
  "$ROOT/Random/Speech.swift" \
  "$ROOT/Random/Platform.swift" \
  "$ROOT/Random/Sound.swift" \
  "$ROOT/Random/Grouping.swift" \
  "$ROOT/Random/History.swift" \
  "$ROOT/Random/AppModel.swift" \
  "$ROOT/Tests/main.swift"

"$ROOT/build/LogicTests"

echo
echo "── 数据隔离检查 ──"
ROSTER_AFTER="$(shasum -a 256 "$REAL_ROSTER" 2>/dev/null | awk '{print $1}')"
if [ -z "$ROSTER_BEFORE" ] && [ -z "$ROSTER_AFTER" ]; then
  echo "  ℹ️ 本机没有导入过名单，跳过"
elif [ "$ROSTER_BEFORE" = "$ROSTER_AFTER" ]; then
  echo "  ✅ 自测没有碰真实名单文件"
else
  echo "  ❌ 自测改动了真实名单文件！$REAL_ROSTER"
  fail=1
fi

echo
echo "── 源码检查 ──"

fail=0
# 注意用 -F（固定字符串）：检查串里经常含 ** 《》 ( ) 等字符，
# 当正则解释会报 "bad regex" 或悄悄匹配错（踩过：'**不朗读**' 被当成重复操作符）。
need() { # $1=文件 $2=要包含的字面串 $3=说明
  if grep -qF -- "$2" "$ROOT/Random/$1" 2>/dev/null; then
    echo "  ✅ $3"
  else
    echo "  ❌ $3"
    fail=1
  fi
}
none() { # $1=文件 $2=不该出现的字面串 $3=说明
  if grep -qF -- "$2" "$ROOT/Random/$1" 2>/dev/null; then
    echo "  ❌ $3"
    grep -nF -- "$2" "$ROOT/Random/$1"
    fail=1
  else
    echo "  ✅ $3"
  fi
}

need Sound.swift      "func victory()"        "音效层提供胜利钟声"
need Sound.swift      "func tick("            "音效层提供抽取鼓点"
need AppModel.swift   "Sound.shared.victory"  "点名/抽取落定播放胜利音效"
need AppModel.swift   "Sound.shared.tick"     "抽取过程播放鼓点"
need AppModel.swift   "tickEnd"               "鼓点支持渐密（tick → tickEnd）"
need AppModel.swift   "var soundOn: Bool = true" "音效默认开启"
need SettingsView.swift "soundOn"             "设置页可关闭音效"
need AppModel.swift   'announcement(for'      "点名播报使用「有请」文案"

none AppModel.swift   "点　名"                "按钮文案不再有全角空格（点　名）"
none AppModel.swift   "抽　取"                "按钮文案不再有全角空格（抽　取）"
none DesignKit.swift  "struct LabeledStepper" "加减按钮式步进器已整体移除"
need ClassroomViews.swift "pickedNames"       "课堂页支持同时展示多个姓名"
need DesignKit.swift  "struct ConfettiBurst"  "彩带特效组件已就位"
need DesignKit.swift  "struct NumberField"    "数字输入框组件已就位"

# 3.0：特效/音效数量级跃升的那一层
need Sound.swift      "private func synth("    "25 种音色共用一个参数化合成器（不是各写一遍）"
need Sound.swift      "static func normalize"  "音色响度自动归一（随机音色不会变成随机音量）"
need Sound.swift      "enum Family"            "落定音分五族（设置页菜单按族分组）"
need DesignKit.swift  "struct BurstSpec"       "24 种特效走参数化预设"
need DesignKit.swift  "sway: Double = 0"       "粒子支持横向摆动（雪花/花瓣才会飘）"
need AppModel.swift   "var pickSpeed"          "抽取节奏可调"
need AppModel.swift   "duration * effectivePickSpeed" "节奏倍率在统一入口生效（8 个工具都跟着变）"
need AppModel.swift   "var soundVolume"        "音效音量可调"
need ToolViews.swift  "struct SequenceView"    "随机顺序工具已就位"
none DesignKit.swift  "return [CelebrationParticle]()" "没有空壳特效（每种都必须真出粒子）"

need RosterFormat.swift "struct RosterFormat"  "规范名单格式解析器已就位"
need AppModel.swift     "func loadRoster"      "支持导入外部名单文件"
need AppModel.swift     "func clearRoster"     "支持移除已导入名单"
need AppModel.swift     "var hasClasses"       "提供「是否已导入名单」判定"
need RootView.swift     "importRosterViaPanel" "工具栏提供导入名单入口"
need RootView.swift     "struct NoRosterView"  "未导入名单时显示引导页"
need RootView.swift     "gradeGroups"          "侧边栏按年级分组"
need RootView.swift     "expandedGrades"       "年级分组可折叠"
need DesignKit.swift    "struct CardGroup"      "设置行合并成组（组内细线，系统设置的做法）"
none DesignKit.swift    "glassEffect"           "内容层不再自绘液态玻璃（HIG：玻璃只用于导航层）"
none RootView.swift     "WindowWidthReader"    "不再监听窗口宽度手动收/放边栏"
need RandomApp.swift    "RandomAppDelegate"    "双击名单文件可打开 Random"

need AppModel.swift     "static let shared = AppModel()" "AppModel 单例（SwiftUI 会重复求值默认值）"
need RandomApp.swift    "AppModel.shared"          "App 用单例，不再每次重建都造新实例"
need Speech.swift       "AVSpeechSynthesizer"      "用系统 TTS 引擎朗读（不是 VoiceOver）"
need Speech.swift       "qualityRank"              "语音按档位排序（增强/优质优先，紧凑垫底）"
need Speech.swift       "prefersAssistiveTechnologySettings" "可跟随系统朗读设置（与 VoiceOver 同款语音）"
need SettingsView.swift "跟随系统朗读设置"          "设置页可切换跟随系统"
need Speech.swift       "isSiriVoice"              "能识别 Siri 音色（macOS 列得出 / iOS 不开放）"
need Speech.swift       "siriDisplayName"          "Siri 音色的占位名「声音1」会显示成「Siri · 李慕」"
need SettingsView.swift "Speech.displayName"       "设置页语音列表用可读名，不用系统占位名"
need Speech.swift       "currentVoiceDescription"  "能报出「当前实际用哪个语音」（解释音质差在哪）"
need SettingsView.swift "当前使用"                  "设置页有「当前使用」一行"
need SettingsView.swift "Siri 的声音被系统锁给"        "设置页明说 Siri 音色拿不到，免得用户到处找"
need Speech.swift       "rescanVoices"              "语音列表缓存可失效（下载完语音不用重启 App）"
need SettingsView.swift "重新扫描"                  "设置页能手动重扫语音列表"
none Speech.swift       "cachedChineseVoices"       "语音列表不再是「算完就锁死」的一次性缓存"
need SettingsView.swift "hasHighQualityVoice"      "没装高质量语音时给用户指路"
need AppModel.swift     "Speech.shared.announce"   "本机点名落定后朗读姓名"
need SettingsView.swift "点名后读出姓名"            "设置页可开关朗读"
need Speech.swift       "var rate: Double"         "语速是存储属性（否则滑条拖不动）"
need Platform.swift     "h.isFinite"               "颜色换算挡住 NaN/inf（外部文本可能解析出来）"
need Platform.swift     "lastResolved"             "窗口回调做了同值保护（否则会无限重绘）"
need Platform.swift     "contentMinSize"          "窗口最小尺寸直接压到 NSWindow（不只靠 view 的 frame）"
need RootView.swift     "minWindowWidth"          "窗口下限＝边栏＋内容放得下的宽度"
need RootView.swift     "CollapsibleRows"         "年级分组用卷帘容器展开（高度动画 + 裁切，List 插入行没动画）"
need RootView.swift     "autoCollapseWidth"        "窄窗口自动收起边栏有明确阈值"
need RootView.swift     "guard width < Self.autoCollapseWidth else { return }" "宽度跟随是单向的（宽回来不自动弹出）"
need Platform.swift     "WindowWidthReporter"      "窗口宽度变化有回调（否则窄了也收不起来）"
none RandomApp.swift    "minWidth: 340"           "窗口不再能被拖成 340pt 的窄条"
none RootView.swift     "func toggle(_"           "展开/收起用绝对设值，不用取反（避免被系统翻两次）"
need DesignKit.swift    "deduped"                  "网格去重（ForEach id 冲突会丢渲染）"
need DesignKit.swift    "settleTask"               "彩带收尾任务可取消（切页不留悬挂）"
need DesignKit.swift    "accessibilityLabel(label)" "输入框有无障碍名称"
none Speech.swift       "get { UserDefaults"        "设置项不能写成读写 UserDefaults 的计算属性"
none Speech.swift       "有请"                      "朗读只念名字，不加客套话"
need RootView.swift     "model.selection = .classroom" "侧边栏行直接写 selection（自绘列表没有 List 的置空问题）"

# 随机数字的「抽过的不再抽」—— 老师拿它当抽号器，撞号就是教学事故
need AppModel.swift     "var numNoRepeat"           "随机数字支持「抽过的不再抽」（跨批次）"
need AppModel.swift     "var numDrawn"              "抽过的号码有记忆"
need AppModel.swift     "func resetNumbers"         "随机数字的抽过记录可清空"
need AppModel.swift     "func nextNumbers"          "抽号逻辑抽成纯函数（可连抽验证不重复）"
need AppModel.swift     "func commitNumbers"        "落定才写入抽过池（滚动过程不污染）"
need AppModel.swift     "guard !isLoading else { return }" "加载期间不回写（否则磁盘上的记录被默认值覆盖）"
need ToolViews.swift    "numPoolEmpty"              "抽完后按钮禁用，不会空转"
need ToolViews.swift    "抽过的不再抽"               "随机数字页有「抽过的不再抽」开关"
none AppModel.swift     "guard k <= hi - lo + 1 else" "不再用「超出范围就静默清空」的旧写法"

# 落定特效 / 音效：四种风格 + 每次随机
need AppModel.swift     "enum CelebrationTheme"      "4 种落定特效主题（纯数据，可无头自测）"
need AppModel.swift     "var celebrationStyle"        "特效风格可配置（默认每次随机）"
need AppModel.swift     "var celebrationTheme"        "每次落定现场决定用哪套特效"
need AppModel.swift     "func cheer()"                "所有落定点统一走 cheer()（不会漏换主题）"
need Sound.swift        "enum SoundTheme"             "落定音 4 种风格（钟声/琶音/木琴/电子）"
need Sound.swift        "func beginRound"             "每轮换一套鼓点音色"
need Sound.swift        "makeRiser"                   "抽取末尾插一记上扬音"
need DesignKit.swift    "makeParticles(_ theme"       "特效粒子按主题生成"
need DesignKit.swift    "func draw(_ theme"           "特效按主题绘制"
need DesignKit.swift    "resultPop"                   "落定时结果文字弹一下（抓住视线）"
need SettingsView.swift "落定音风格"                   "设置页可选音效风格"
need SettingsView.swift "落定特效"                     "设置页可选特效主题"
need RootView.swift     "toggleProjection"            "支持投影模式（收边栏 + 全屏）"
none DesignKit.swift    "struct ConfettiParticle"     "旧版单一彩带粒子已替换"

# 应用要能分发给别人，源码里就不能残留任何真实学生姓名
none ClassRoster.swift  "陈南瑾"               "内置名单数据已彻底移除（不含真实姓名）"
none ClassRoster.swift  "names2601"            "不再编译进 2601 班名单"
need ClassRoster.swift  "static let empty"     "提供空名单常量（初始未导入）"
none AppModel.swift     "ClassRoster.classes"  "AppModel 不再引用内置名单常量"

# ── 2.0：随机分组 / 历史记录 / 舞台字号 ──
need Grouping.swift     "enum GroupSplit"        "分组算法是独立的纯函数（可无头自测）"
need Grouping.swift     "shuffled()"             "分组先洗牌再轮流发牌（各组人数最多差 1）"
need AppModel.swift     "func drawGroups"        "分组走一次抽取动画"
need AppModel.swift     "func nextGroups"        "分组逻辑抽成纯函数，自测不等动画"
need AppModel.swift     "func switchClass"       "分组页可以原地换班"
need ToolViews.swift    "struct GroupingView"    "分组界面已就位"
need AppModel.swift     "func logHistory"        "落定结果写进历史时间线"
need AppModel.swift     "func trimHistory"       "历史上限可裁（不无限长）"
need AppModel.swift     "func leastPicked"       "班级页统计「被点得最少」的人"
need AppModel.swift     "func historyCSV"        "历史可导出 CSV"
need History.swift      "func escape"            "CSV 字段转义（逗号 / 引号 / 换行）"
need History.swift      'u{FEFF}'                "CSV 带 UTF-8 BOM（Excel 打开不乱码）"
need HistoryView.swift  "NSSavePanel"            "历史页可另存为 CSV 文件"
need HistoryView.swift  "confirmClear"           "清空历史要二次确认"
need RootView.swift     "HistoryView"            "侧边栏有「历史记录」入口"
need RootView.swift     "搜索班级或工具"           "侧边栏可搜索（18 个班时必需）"
need AppModel.swift     "var stageScale"         "舞台字号可调（投影场景）"
need SettingsView.swift "舞台字号"                "设置页有舞台字号滑条"
need AppModel.swift     "history.v1"             "历史单独落盘（不塞进 state 字典）"


# ── 3.3：每个工具自己的动效 + 自己的声音 ──
#
# 这一版的核心诉求是「十个工具不能长得一样」。所以要钉住两件事：
#   1) 每个工具都有专属的动效组件（不是共用一个 BigNumber 淡入淡出）
#   2) 每轮抽取都把自己的 ToolSound 传下去（不是统一放嘟嘟嘟）
need ToolFlourish.swift "struct SlotRoller"        "滚轮文字组件（花名册往上翻）"
need ToolFlourish.swift "struct CoinStage"         "硬币：绕水平轴翻（纵向压缩）"
need ToolFlourish.swift "struct DiceStage"         "骰子：桌上乱晃 + 落桌砸一下"
need ToolFlourish.swift "struct CardStage"         "抽卡：牌背翻成正面"
need ToolFlourish.swift "struct RPSStage"          "猜拳：两只真的手"
need ToolFlourish.swift "struct GroupShuffleStage" "分组：几摞牌在桌上洗"
need ToolFlourish.swift "struct SequenceStage"     "打乱顺序：前三位一起往上滚"
need ToolFlourish.swift "struct ColorStage"        "随机颜色：色块呼吸 + 落定光晕"
need ToolFlourish.swift "struct SpotlightSweep"    "点名：花名册上的扫描线"
need ToolFlourish.swift "struct YesNoStage"        "是或否：举棋不定的摇摆"
need ToolFlourish.swift "struct MoveButton"        "猜拳：出拳按钮不再三个大蓝块"
need Sound.swift        "enum ToolSound"           "每个工具自己的抽取过程音"
need Sound.swift        "func toolTick"            "过程音按工具分派（不是一套鼓点通用）"
need Sound.swift        "func settle(_ tool"       "实物工具用自己的落定声（骰子/硬币/牌/猜拳）"
need Sound.swift        "var hasOwnSettle"         "区分实物类与抽象抽取（决定要不要插上扬音）"
need ClassroomViews.swift "SpotlightSweep"         "点名页接上扫描线"

# 11 个抽取入口都得传 sound:，漏一个就退回通用嘟嘟声。
tool_sound_calls=$(grep -cE 'sound: \.(pick|number|dice|coin|card|color|letter|rps|yesNo|shuffle),' \
                   "$ROOT/Random/AppModel.swift" 2>/dev/null || echo 0)
tool_sound_calls=${tool_sound_calls//[!0-9]/}
tool_sound_calls=${tool_sound_calls:-0}
if [ "$tool_sound_calls" -ge 11 ]; then
  echo "  ✅ 11 个抽取入口都指定了工具音色（实际 ${tool_sound_calls} 处）"
else
  echo "  ❌ 只有 ${tool_sound_calls} 处指定了工具音色（应为 11）"
  fail=1
fi

# ── 3.4：随机顺序页也要能选班级 ──
#
# 顺序是按「当前班」排的，页面上却只有一个「打乱顺序」按钮 ——
# 老师想换班就得先去侧边栏点别的班，等于中途离开这个工具。
# 分组页早就支持原地换班，顺序页漏了。
need ToolViews.swift    "顺序班级"             "随机顺序页能原地选班级（和分组页一致）"
need AppModel.swift     "sequenceResult = []"  "换班清掉上一个班的顺序（不会挂着别人的第 1 位）"
need AppModel.swift     "func switchClass"     "换班不跳页（走 switchClass）"


# ── 单平台 + 无同步的防回归（2026-10-26 起只交付 macOS）──
none_in_src() { # $1=不该出现的字面串 $2=说明
  if grep -rqF -- "$1" "$ROOT/Random" --include="*.swift" 2>/dev/null; then
    echo "  ❌ $2"
    grep -rnF -- "$1" "$ROOT/Random" --include="*.swift" | head -5
    fail=1
  else
    echo "  ✅ $2"
  fi
}

none_in_src "os(iOS)"        "源码里不再有任何 iOS 分支"
none_in_src "import UIKit"   "不再 import UIKit"
none_in_src "AVAudioSession" "不再配置 iOS 音频会话"
none_in_src "SyncEngine"     "同步引擎已移除"
none_in_src "SyncPayload"    "同步报文类型已移除"
none_in_src "broadcastTool"  "工具结果不再广播"
none_in_src "offlineSummary" "离线汇总提示已移除"
none_in_src "NotificationCenter.default.post" "不再发本地通知"

# 3.1：字号必须落在 DesignKit.Type 的阶梯上（见那边的注释）。
# 半点值是 3.0 的遗留问题：11.5 和 12 并排时肉眼觉得"没对齐"，但说不出哪里错。
none_in_src "size: 8.5"  "字号阶梯：不再有 8.5"
none_in_src "size: 10.5" "字号阶梯：不再有 10.5"
none_in_src "size: 11.5" "字号阶梯：不再有 11.5"
none_in_src "size: 12.5" "字号阶梯：不再有 12.5"
if grep -rqF -- "enum Type {" "$ROOT/Random" --include="*.swift"; then
  echo "  ✅ 字号阶梯 Type 存在"
else
  echo "  ❌ 找不到字号阶梯 Type"
  fail=1
fi

for f in SyncEngine.swift Notify.swift; do
  if [ -e "$ROOT/Random/$f" ]; then
    echo "  ❌ $f 应已删除"
    fail=1
  else
    echo "  ✅ $f 已删除"
  fi
done

if grep -q "IPHONEOS_DEPLOYMENT_TARGET\|SUPPORTED_PLATFORMS = \"iphone" "$ROOT/Random.xcodeproj/project.pbxproj"; then
  echo "  ❌ 工程里还有 iOS 构建配置"
  fail=1
else
  echo "  ✅ 工程只有 macOS 构建配置"
fi
if grep -q "SDKROOT = macosx;" "$ROOT/Random.xcodeproj/project.pbxproj"; then
  echo "  ✅ SDKROOT 指向 macOS"
else
  echo "  ❌ SDKROOT 不是 macOS"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo
  echo "源码检查未通过 ❌"
  exit 1
fi
echo "  ✅ 源码检查全部通过"
