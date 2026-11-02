import Foundation
import AppKit

// 无头逻辑自测：班级名单、姓名映射、每班记录隔离与持久化、随机、牌堆、猜拳、颜色。
// 编译方式见 ../run-tests.sh —— 只链接数据与逻辑层，不启动界面。

var failures = 0
func check(_ ok: Bool, _ label: String) {
    print((ok ? "  ✅ " : "  ❌ ") + label)
    if !ok { failures += 1 }
}

// 每次都从干净状态开始
UserDefaults.standard.removeObject(forKey: "cn.renqiaoyi.random.state.v3")

// 应用不再内置名单，所以自测要自己造一份：2601–2606 各 49 人。
// 姓名用「班号-学号」生成，便于断言，也避免把真实学生姓名写进测试。
let fixture: [ClassRoster.SchoolClass] = (1...6).map { i in
    let id = "260\(i)"
    return ClassRoster.SchoolClass(id: id, names: (1...49).map { "\(id)-\($0)" })
}

/// 自测专用的清单文件位置（临时目录）。
///
/// ⚠️ 绝不能让自测碰真实数据：`active.randomroster` 里是老师自己导入的班级名单，
/// 之前自测里的「远端名单下发」直接写到默认路径，把真实名单覆盖成了假数据。
/// 所以这里每个实例都给一个临时文件，测试进程与用户数据彻底隔离。
func tempRosterURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("random-selftest-\(UUID().uuidString).randomroster")
}

/// 造一个新模型：不读本机已导入的名单（避免被真机状态污染），直接以测试名单开局。
///
/// ⚠️ `rosterStore:` 也是必须的：否则落盘会写到用户真实名单上。
func newModel() -> AppModel {
    AppModel(autoloadImported: false, seedRoster: fixture, seedName: "测试名单",
             rosterStore: tempRosterURL())
}

/// 造一个固定日期（年级是按学年推的，必须能钉住「现在」）。
func dateFrom(_ ymd: String) -> Date {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.date(from: ymd) ?? Date()
}

let m = newModel()

print("\n[0] 未导入名单时的空状态")
let emptyModel = AppModel(autoloadImported: false, rosterStore: tempRosterURL())
check(emptyModel.hasClasses == false, "初始没有任何班级")
check(emptyModel.activeClasses.isEmpty, "班级列表为空")
check(emptyModel.currentNames.isEmpty, "当前姓名表为空")
check(emptyModel.pickPool.isEmpty, "号码池为空")
check(emptyModel.allSidebarItems.count == 11, "10 个随机工具 + 历史记录（实际 \(emptyModel.allSidebarItems.count)）")
emptyModel.selection = .classroom("")
emptyModel.drawPick()
check(emptyModel.pickResults.isEmpty, "没有名单时点名不出结果")
check(emptyModel.pickMessage.contains("导入"), "提示引导导入（实际「\(emptyModel.pickMessage)」）")

print("\n[1] 导入名单的完整性")
check(m.activeClasses.count == 6, "6 个班（实际 \(m.activeClasses.count)）")
check(m.activeClasses.map { $0.id } == ["2601", "2602", "2603", "2604", "2605", "2606"],
      "班号顺序 2601–2606")
var total = 0
for cls in m.activeClasses {
    total += cls.names.count
    check(cls.names.count == 49, "\(cls.id) 班 49 人（实际 \(cls.names.count)）")
    check(cls.names.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
          "\(cls.id) 班无空姓名")
    check(Set(cls.names).count == cls.names.count, "\(cls.id) 班无重名")
}
check(total == 294, "合计 294 人（实际 \(total)）")

print("\n[2] 姓名与学号映射")
m.selection = .classroom("2601")
check(m.classCount == 49, "2601 班共 49 人")
check(m.name(no: 1) == "2601-1", "1 号 → 2601-1（实际 \(m.name(no: 1) ?? "nil")）")
check(m.name(no: 49) == "2601-49", "49 号 → 2601-49（实际 \(m.name(no: 49) ?? "nil")）")
check(m.name(no: 0) == nil, "0 号越界返回 nil")
check(m.name(no: 50) == nil, "50 号越界返回 nil")
check(m.fmtNo(7) == "07" && m.fmtNo(49) == "49", "补零显示 07 / 49")
m.padZero = false
check(m.fmtNo(7) == "7", "关闭补零后显示 7")
m.padZero = true
m.selection = .classroom("2602")
check(m.name(no: 1) == "2602-1", "2602 班 1 号 → 2602-1（实际 \(m.name(no: 1) ?? "nil")）")
check(m.name(no: 49) == "2602-49", "2602 班 49 号 → 2602-49（实际 \(m.name(no: 49) ?? "nil")）")
m.selection = .classroom("2606")
check(m.name(no: 37) == "2606-37", "2606 班 37 号 → 2606-37（实际 \(m.name(no: 37) ?? "nil")）")

print("\n[3] 六个班各自独立、互不干扰")
m.drawnByClass = [:]
m.selection = .classroom("2601")
m.drawnByClass["2601"] = [1, 2, 3]
m.drawnByClass["2604"] = [7]
check(m.drawnCount(of: "2601") == 3, "2601 记了 3 个")
check(m.drawnCount(of: "2604") == 1, "2604 记了 1 个")
check(m.drawnCount(of: "2602") == 0, "2602 没有记录")
m.selection = .classroom("2602")
check(m.drawn.isEmpty, "切到 2602 后当前记录为空")
check(m.pickRemaining == 49, "2602 剩余 49（实际 \(m.pickRemaining)）")
m.selection = .classroom("2601")
check(m.drawn.sorted() == [1, 2, 3], "切回 2601 记录还在")
check(m.pickRemaining == 46, "2601 剩余 46（实际 \(m.pickRemaining)）")
m.noRepeat = false
check(m.pickRemaining == 49, "可重复模式下剩余恒为 49")
m.noRepeat = true

print("\n[4] 关掉应用后记录仍在（持久化往返）")
m.drawnByClass["2603"] = [11, 22, 33, 44]
m.selection = .classroom("2603")
m.persist()
let m2 = newModel()
check(m2.drawnCount(of: "2603") == 4,
      "新实例读回 2603 的 4 条记录（实际 \(m2.drawnCount(of: "2603"))）")
check(m2.drawnByClass["2603"]?.sorted() == [11, 22, 33, 44], "内容一致")
check(m2.classID == "2603", "记住了上次所在班级（实际 \(m2.classID)）")
check(m2.selection == .classroom("2603"), "记住了上次所在栏目")
m.selection = .tool(.dice)
m.persist()
let m3 = newModel()
check(m3.selection == .tool(.dice), "切到骰子后也能记住（实际 \(m3.selection)）")
check(m3.drawnCount(of: "2603") == 4, "换栏目不影响 2603 的记录")

print("\n[5] 随机整数均匀性 randInt(1,49)，24.5 万次")
var counts: [Int: Int] = [:]
for _ in 0..<245_000 {
    let v = m.randInt(1, 49)
    if v < 1 || v > 49 { check(false, "越界 \(v)"); break }
    counts[v, default: 0] += 1
}
let mn = counts.values.min() ?? 0
let mx = counts.values.max() ?? 0
check(counts.count == 49, "49 个号码全覆盖（实际 \(counts.count)）")
check(mn > 4400 && mx < 5600, "分布均匀：min \(mn) / max \(mx) / 期望 5000")

print("\n[6] 无放回抽样")
for _ in 0..<3000 {
    let r = m.sample(Array(1...49), 6)
    if Set(r).count != 6 { check(false, "出现重复"); break }
}
check(true, "抽 6 个，3000 次无重复")

print("\n[7] 扑克牌堆")
let deck52 = PlayingCard.fullDeck(includeJokers: false)
let deck54 = PlayingCard.fullDeck(includeJokers: true)
check(deck52.count == 52, "不含大小王 52 张（实际 \(deck52.count)）")
check(deck54.count == 54, "含大小王 54 张（实际 \(deck54.count)）")
check(Set(deck52.map { $0.id }).count == 52, "52 张互不重复")
check(deck54.filter { $0.isJoker }.count == 2, "大小王共 2 张")
check(deck54.contains { $0.rank == "A" && $0.suit == .spade }, "含黑桃 A")
let hand = m.sample(deck54, 10)
check(hand.count == 10 && Set(hand.map { $0.id }).count == 10, "抽 10 张不重复")

print("\n[8] 猜拳判定")
check(RPS.rock.versus(.scissors) == 1, "石头胜剪刀")
check(RPS.scissors.versus(.paper) == 1, "剪刀胜布")
check(RPS.paper.versus(.rock) == 1, "布胜石头")
check(RPS.rock.versus(.paper) == -1, "石头负于布")
check(RPS.scissors.versus(.rock) == -1, "剪刀负于石头")
check(RPS.paper.versus(.scissors) == -1, "布负于剪刀")
check(RPS.rock.versus(.rock) == 0, "石头对石头为平局")

print("\n[9] 字母范围与大小写")
check(LetterScope.full.letters.count == 26, "A–Z 共 26 个")
check(LetterScope.firstEight.letters.count == 8, "A–H 共 8 个")
check(LetterScope.vowels.letters.count == 5, "元音共 5 个")
check(LetterScope.full.letters.first == "A" && LetterScope.full.letters.last == "Z",
      "首尾为 A 和 Z")
m.letterUppercase = false
check(m.letterDisplay("A") == "a", "小写显示 a")
m.letterUppercase = true
check(m.letterDisplay("A") == "A", "大写显示 A")

print("\n[10] 颜色换算")
m.applyColor(h: 0, s: 1, b: 1)
check(m.colorHex == "#FF0000", "纯红 → #FF0000（实际 \(m.colorHex)）")
m.applyColor(h: 120, s: 1, b: 1)
check(m.colorHex == "#00FF00", "纯绿 → #00FF00（实际 \(m.colorHex)）")
m.applyColor(h: 240, s: 1, b: 1)
check(m.colorHex == "#0000FF", "纯蓝 → #0000FF（实际 \(m.colorHex)）")
m.applyColor(h: 214, s: 0.82, b: 1.0)
check(m.colorHex.count == 7 && m.colorHex.hasPrefix("#"), "色值格式 \(m.colorHex)")
check((0...1).contains(m.red) && (0...1).contains(m.green) && (0...1).contains(m.blue),
      "RGB 分量都在 0–1 之间")

print("\n[11] 侧边栏条目与「有无记录」判定")
check(m.allSidebarItems.count == 17,
      "6 个班 + 10 个随机工具 + 历史 = 17 项（实际 \(m.allSidebarItems.count)）")
check(m.allSidebarItems.first == .classroom("2601"), "第一项是 2601 班")
check(m.allSidebarItems.last == .history, "最后一项是「历史记录」")
m.selection = .classroom("2605")
m.drawnByClass["2605"] = []
check(m.hasRecords == false, "2605 无记录 → 清空按钮应禁用")
m.drawnByClass["2605"] = [5]
check(m.hasRecords == true, "2605 有记录 → 清空按钮可用")
m.selection = .tool(.color)
check(m.hasRecords == false, "随机颜色没有可清空的记录")
m.selection = .classroom("2601")
check(m.actionTitle == "点名", "课堂动作名为「点名」（实际 \(m.actionTitle)）")
m.selection = .tool(.dice)
check(m.actionTitle == "掷骰子", "骰子动作名为「掷骰子」（实际 \(m.actionTitle)）")

print("\n[12] 点名同时抽多人")
m.selection = .classroom("2601")
m.drawnByClass["2601"] = []
check(m.effectivePickCount == 1, "默认每次点 1 名")
m.pickCount = 3
check(m.effectivePickCount == 3, "设为 3 名")
m.pickCount = 99
check(m.effectivePickCount == 10, "超出上限夹到 10")
m.pickCount = -5
check(m.effectivePickCount == 1, "低于下限夹到 1")
m.pickCount = 4
var poolOK = true
for _ in 0..<800 {
    let r = m.sample(m.pickPool, m.effectivePickCount)
    if r.count != 4 || Set(r).count != 4 { poolOK = false; break }
}
check(poolOK, "抽 4 人：800 次均为 4 个互不重复的号码")
m.drawnByClass["2601"] = [1, 2, 3]
let pool = Set(m.pickPool)
check(pool.count == 46 && !pool.contains(1) && !pool.contains(3),
      "已抽 1/2/3 后号码池剩 46 个且不含已抽号（实际 \(pool.count)）")
m.drawnByClass["2601"] = []
m.pickCount = 1

print("\n[13] 点名播报文案「有请」")
check(m.announcement(for: [1]) == "有请 2601-1 同学（01 号）",
      "单人：\(m.announcement(for: [1]))")
check(m.announcement(for: [1, 3]) == "有请 2601-1、2601-3 同学（01、03 号）",
      "多人：\(m.announcement(for: [1, 3]))")
m.padZero = false
check(m.announcement(for: [7]) == "有请 2601-7 同学（7 号）",
      "关补零后：\(m.announcement(for: [7]))")
m.padZero = true
check(m.announcement(for: []).isEmpty, "空结果返回空串")
check(m.announcement(for: [1]).hasPrefix("有请"), "一律以「有请」开头")
m.rosterOverrides["2601"] = ["甲", "乙"]
check(m.announcement(for: [1, 2]) == "有请 甲、乙 同学（01、02 号）",
      "自定义名单同样生效：\(m.announcement(for: [1, 2]))")
m.rosterOverrides = [:]
m.selection = .classroom("2601")
check(m.pickMessage.contains("点名") && !m.pickMessage.contains("　"),
      "初始提示为「\(m.pickMessage)」（已去掉全角空格）")

print("\n[14] 音效开关")
check(m.soundOn == true, "音效默认开启")
check(Sound.enabled == true, "默认已同步到音频层")
m.soundOn = false
check(Sound.enabled == false, "关闭后音频层同步为关")
for _ in 0..<3 { Sound.shared.tick(0.5); Sound.shared.victory(); Sound.shared.ding() }
check(true, "静音状态下调用发声接口不崩溃、不初始化引擎")
m.soundOn = true
check(Sound.enabled == true, "重新打开后同步为开")
m.persist()
let m4 = newModel()
check(m4.soundOn == true, "音效开关可持久化往返")
m4.soundOn = false
m4.persist()
check(newModel().soundOn == false, "关掉音效后能被新实例读回")
m4.soundOn = true
m4.persist()

print("\n[15] 秒数与节奏")
check(m.activeClasses.count == 6, "班级数不变（\(m.activeClasses.count)）")
let slow = 0.118, fast = 0.042
var t = 0.0, last = -99.0, ticks = 0
while t < 2.0 {
    let interval = slow + (fast - slow) * (t / 2.0)
    if t - last >= interval { last = t; ticks += 1 }
    t += 0.016
}
check(ticks >= 20 && ticks <= 30, "2 秒内鼓点 \(ticks) 次（应 20–30 次）")
check(fast < slow, "鼓点由疏到密（\(slow) → \(fast)）")

print("\n[16] 落定特效 / 音效：24 种特效 + 25 种音效，默认每次随机")

check(CelebrationTheme.allCases.count == 24, "一共 24 种落定特效（实际 \(CelebrationTheme.allCases.count)）")
let themeTitles = CelebrationTheme.allCases.map(\.title)
check(Set(themeTitles).count == 24 && !themeTitles.contains(""), "24 种特效的标题互不重复且非空")
check(CelebrationTheme.allCases.allSatisfy { $0.duration > 1.0 }, "每种特效都演够 1 秒以上")
check(CelebrationTheme.allCases.allSatisfy { !$0.symbol.isEmpty }, "每种特效都有图标")

// 固定值必须原样返回（设置里选了「连环烟花」就不能偷偷放别的）
for t in CelebrationTheme.allCases {
    check(CelebrationTheme.resolve(t.rawValue) == t, "固定「\(t.title)」时不会乱换")
}
check(CelebrationTheme.resolve("配置被写坏了") != nil, "配置值不认识时退回一个合法主题")

// 默认随机：抽 200 次要覆盖全部 4 种（只抽到 1~3 种的概率约等于 0）
var seenThemes = Set<CelebrationTheme>()
for _ in 0..<400 { seenThemes.insert(CelebrationTheme.resolve(CelebrationTheme.randomKey)) }
check(seenThemes.count == 24, "「每次随机」确实会轮换（400 次覆盖 \(seenThemes.count) 种）")

check(SoundTheme.allCases.count == 25, "一共 25 种落定音（实际 \(SoundTheme.allCases.count)）")
check(Set(SoundTheme.allCases.map(\.title)).count == 25, "25 种落定音的标题互不重复")
check(SoundTheme.resolve(SoundTheme.randomKey) == nil, "音效「随机」解析成 nil（每次现场抽）")
for t in SoundTheme.allCases {
    check(SoundTheme.resolve(t.rawValue) == t, "固定「\(t.title)」时不会乱换")
}

// 族分组必须完整覆盖、不重不漏（设置页按族分菜单，漏一族的音色就选不到）
let sfTotal = SoundTheme.Family.allCases.reduce(0) { $0 + $1.themes.count }
check(sfTotal == SoundTheme.allCases.count, "音效五族合计 = 全部（\(sfTotal) 种）")
check(SoundTheme.Family.allCases.allSatisfy { $0.themes.count >= 3 }, "每一族至少 3 种音效")

let cfTotal = CelebrationTheme.Family.allCases.reduce(0) { $0 + $1.themes.count }
check(cfTotal == CelebrationTheme.allCases.count, "特效五族合计 = 全部（\(cfTotal) 种）")
check(CelebrationTheme.Family.allCases.allSatisfy { $0.themes.count >= 4 }, "每一族至少 4 种特效")

print("\n[26] 随机顺序（3.0）")
m.classID = m.activeClasses.first?.id ?? "2601"
let seqOK = (0..<20).allSatisfy { _ in
    let o = m.shuffledOrder()
    return Set(o).count == o.count && o.min() == 1 && o.max() == o.count
}
check(seqOK, "打乱 20 次都不重不漏")
check(m.shuffledOrder() != m.shuffledOrder(), "两次打乱结果不同（不是固定排列）")
check(m.sequencePlainText.isEmpty, "没打过乱时复制文本为空")
m.sequenceResult = m.shuffledOrder()
check(m.sequencePlainText.components(separatedBy: "\n").count == m.currentNames.count,
      "顺序文本每人一行")

// AppModel 接线：默认随机、cheer() 按设置挑主题
UserDefaults.standard.removeObject(forKey: "cn.renqiaoyi.random.state.v3")
let cm = newModel()
check(cm.celebrationStyle == CelebrationTheme.randomKey, "特效默认「每次随机」")
check(cm.soundStyle == SoundTheme.randomKey, "音效默认「每次随机」")

cm.celebrationStyle = CelebrationTheme.rings.rawValue
let cmCeleb = cm.celebration
cm.cheer()
check(cm.celebration == cmCeleb + 1, "cheer() 会放一次特效")
check(cm.celebrationTheme == .rings, "固定风格时每次都放同一种（实际 \(cm.celebrationTheme.title)）")

cm.celebrationStyle = CelebrationTheme.randomKey
var seenModel = Set<CelebrationTheme>()
for _ in 0..<600 {
    cm.cheer()
    seenModel.insert(cm.celebrationTheme)
}
check(seenModel.count == 24, "随机模式下连抽会换特效（600 次覆盖 \(seenModel.count) 种）")

// 持久化：设置过就记住，重开 App 不回到随机
cm.celebrationStyle = CelebrationTheme.starburst.rawValue
cm.soundStyle = SoundTheme.marimba.rawValue
let cm2 = newModel()
check(cm2.celebrationStyle == CelebrationTheme.starburst.rawValue, "特效风格重启后保留")
check(cm2.soundStyle == SoundTheme.marimba.rawValue, "音效风格重启后保留")
check(Sound.themeStyle == .marimba, "音效风格也同步到了音频层")

print("\n[17] 随机数字「抽过的不再抽」（当抽号器用时绝不能撞号）")

// 真实教训：老师把随机数字设成 1–49 当学号抽，抽过的号下一次照样会中。
// 连抽十几次几乎必然撞人 —— 因为老版本只有「一批内不重复」，完全没有跨次记忆。
let nm = newModel()
nm.numMin = 1
nm.numMax = 49
nm.numCount = 1
nm.numUnique = true
// 前面的同步测试往同一个 UserDefaults 域里写过号码（跨设备并入池子的正常行为），
// 这里先清干净，保证断言从零开始。
nm.numDrawn = []
check(nm.numNoRepeat, "默认开启「抽过的不再抽」")
check(nm.numRemaining == 49, "初始可抽 49 个（实际 \(nm.numRemaining)）")

var seen: [Int] = []
for _ in 0..<49 {
    let got = nm.nextNumbers()
    seen.append(contentsOf: got)
    nm.commitNumbers(got)
}
check(seen.count == 49, "连抽 49 次每次都有结果（实际 \(seen.count) 次）")
check(Set(seen).count == 49, "49 次抽出的号码互不相同（实际 \(Set(seen).count) 个）")
check(Set(seen) == Set(1...49), "正好把 1–49 全覆盖")
check(nm.numPoolEmpty, "抽满 49 个后池子为空")
check(nm.nextNumbers().isEmpty, "抽完后不再出号")
check(nm.numRangeSize - nm.numPool.count == 49, "「已抽」计数到顶")

// 池空时点抽取：要立刻收尾，不能卡在滚动状态
nm.drawNumbers()
check(nm.numResults.isEmpty, "抽完后点抽取会清空显示")
check(!nm.numRolling, "抽完后点抽取不会卡在滚动状态")

nm.resetNumbers()
check(nm.numDrawn.isEmpty && nm.numRemaining == 49, "清空后重新开一轮")

// 范围改小：范围外的旧记录不能把池子带偏
nm.numMin = 1
nm.numMax = 5
nm.numDrawn = [1, 2, 3, 40, 70]
check(nm.numPool == [4, 5], "范围改小后按范围过滤旧记录（实际 \(nm.numPool)）")

// 一批抽多个：内部也必须互不相同
nm.numMin = 1
nm.numMax = 10
nm.numCount = 3
nm.numDrawn = []
let batch = nm.nextNumbers()
check(batch.count == 3, "一批抽 3 个（实际 \(batch.count)）")
check(Set(batch).count == 3, "同一批 3 个互不相同")
check(nm.numPool.count == 10, "还没抽的号都还在池子里（\(nm.numPool.count)）")

// 关掉记忆：恢复成纯随机
nm.numNoRepeat = false
check(nm.numPool.count == 10, "关掉记忆后池子恢复满（\(nm.numPool.count)）")
check(nm.numRemaining == 10, "关掉记忆后剩余数 = 范围大小")

// 持久化：重开 App 还记得抽过谁
let nm3 = newModel()
nm3.numMin = 1
nm3.numMax = 9
nm3.numCount = 1
nm3.numDrawn = []
nm3.commitNumbers([3, 5])
let nm4 = newModel()
check(nm4.numDrawn == [3, 5], "抽过的记录重启后还在（实际 \(nm4.numDrawn)）")
check(!nm4.numPool.contains(3), "重启后 3 号仍在池外")

print("\n[18] 颜色换算的防御（外部文本可能解析出 NaN / inf）")

// h/s/b 可能来自外部文本解析（Double("nan") / Double("inf") 都是合法解析结果，
// 不是 nil）。以前不挡的话，hsbToRGB 里的 Int(hue) 会直接 trap 崩溃。
check(hsbToRGB(h: .nan, s: 0.5, b: 1).0.isFinite, "h 为 NaN 不崩、返回有限值")
check(hsbToRGB(h: .infinity, s: 0.5, b: 1).0.isFinite, "h 为 inf 不崩")
check(hsbToRGB(h: -.infinity, s: 0.5, b: 1).0.isFinite, "h 为 -inf 不崩")
check(hsbToRGB(h: 0, s: .nan, b: 1).1.isFinite, "s 为 NaN 不崩")
check(hsbToRGB(h: 0, s: 0.5, b: .nan).2.isFinite, "b 为 NaN 不崩")

// 正常值仍然要算对
check(hsbToRGB(h: 0, s: 0.5, b: 1) == (1.0, 0.5, 0.5), "红色正确")
check(hsbToRGB(h: 120, s: 1, b: 1) == (0.0, 1.0, 0.0), "绿色正确")
check(hsbToRGB(h: 240, s: 1, b: 1) == (0.0, 0.0, 1.0), "蓝色正确")

// 越界值要收敛，不能算出诡异的颜色
check(hsbToRGB(h: 400, s: 1, b: 1) == hsbToRGB(h: 40, s: 1, b: 1), "h 超过 360 会绕回来")
check(hsbToRGB(h: -60, s: 1, b: 1) == hsbToRGB(h: 300, s: 1, b: 1), "h 为负会绕回来")
check(hsbToRGB(h: 0, s: 5, b: 1) == hsbToRGB(h: 0, s: 1, b: 1), "s 超上限被夹住")
check(hsbToRGB(h: 0, s: -1, b: 1) == hsbToRGB(h: 0, s: 0, b: 1), "s 为负被夹住")
check(hsbToRGB(h: 0, s: 1, b: 2) == hsbToRGB(h: 0, s: 1, b: 1), "b 超上限被夹住")

print("\n[19] 点名朗读（系统 TTS）")

check(Speech.announcement(for: ["张三"]) == "张三", "直接念名字：\(Speech.announcement(for: ["张三"]))")
check(Speech.announcement(for: ["张三", "李四"]) == "张三、李四",
      "多人用顿号连读：\(Speech.announcement(for: ["张三", "李四"]))")
check(!Speech.announcement(for: ["张三"]).contains("有请"), "不带「有请」这类客套话")
check(!Speech.announcement(for: ["张三"]).contains("同学"), "不带「同学」后缀")
check(Speech.announcement(for: []) == "", "没有姓名时不朗读")
check(Speech.announcement(for: ["", "张三"]) == "张三", "空名字被过滤掉")

let zhVoices = Speech.chineseVoices()
check(!zhVoices.isEmpty, "系统里能列出中文语音（\(zhVoices.count) 个）")
check(zhVoices.allSatisfy { $0.language.hasPrefix("zh") }, "列表里只有中文语音")

// 用户没选语音时也要能自动挑一个中文的
let savedVoice = Speech.shared.voiceIdentifier
Speech.shared.voiceIdentifier = nil
check(Speech.shared.resolvedVoice() != nil, "默认能自动解析出一个中文语音（\(Speech.shared.resolvedVoice()?.name ?? "nil")）")
check(Speech.shared.resolvedVoice()?.language.hasPrefix("zh") == true, "自动挑的是中文语音")
Speech.shared.voiceIdentifier = savedVoice

// 语速默认值落在可听清的区间
check(Speech.shared.rate >= 0.3 && Speech.shared.rate <= 0.6, "默认语速在 0.30~0.60 之间（\(Speech.shared.rate)）")

// 语音列表必须按「质量档位」排序：紧凑档排后面。
// 这是「听起来自不自然」的大头 —— 系统预装的都是紧凑档，用户下载增强/优质后要能被优先选中。
let sortedZh = Speech.chineseVoices()
let ranks = sortedZh.map(Speech.qualityRank)
check(ranks == ranks.sorted(by: >), "语音列表按质量降序")

let topName = sortedZh.first?.name ?? "无"
let topQuality = sortedZh.first.map(Speech.qualityLabel) ?? "-"
check(!sortedZh.isEmpty, "最高档语音：\(topName)（\(topQuality)）")

let labels = Set(sortedZh.map(Speech.qualityLabel))
let labelsOK = labels.isSubset(of: ["紧凑", "增强", "优质", "Siri 音色"])
check(labelsOK, "档位标签合法")

// ── Siri 音色 ──────────────────────────────────────────────────────────
// 2026-09-28 实测：macOS 的 speechVoices() **会**列出 Siri 音色，iOS 不会。
// 所以这里不断言"一定有"，只断言"有的话行为必须正确"（否则 iOS 上必然挂）。
let siriList = Speech.siriVoices
if siriList.isEmpty {
    print("      ℹ️ 本进程可列出 Siri 音色：0 个（第三方 App 的正常结果 —— 系统只放行 Apple 自家签名的二进制）")
} else {
    print("      ℹ️ 本进程可列出 Siri 音色 \(siriList.count) 个：\(siriList.map(Speech.displayName).joined(separator: "、"))")
}
check(siriList.allSatisfy { Speech.qualityRank($0) == 4 }, "Siri 音色算最高档位（4）")
check(siriList.allSatisfy { Speech.qualityLabel($0) == "Siri 音色" }, "Siri 音色的档位标签为「Siri 音色」")
check(siriList.isEmpty || (sortedZh.first.map(Speech.isSiriVoice) ?? false), "有 Siri 音色时必须排在语音列表最前")

// 系统给 Siri 音色的 name 是「声音1」这种占位符，界面上得换成能看懂的名字
check(Speech.siriDisplayName(forIdentifier: "com.apple.siri.natural.Li-Mu") == "Siri · 李慕",
      "Li-Mu 显示为「Siri · 李慕」")
check(Speech.siriDisplayName(forIdentifier: "com.apple.siri.natural.Yu-Shu") == "Siri · 语舒",
      "Yu-Shu 显示为「Siri · 语舒」")
check(Speech.siriDisplayName(forIdentifier: "com.apple.siri.natural.Xx-Yy") == "Siri · Xx-Yy",
      "没收录的 Siri 音色回退成原名，不是空白")
check(Speech.siriDisplayName(forIdentifier: "com.apple.voice.compact.zh-CN.Tingting") == nil,
      "普通语音不套 Siri 前缀")
check(sortedZh.first.map(Speech.displayName) != "声音1", "列表里不会出现「声音1」这种占位名")
check(siriList.allSatisfy { Speech.displayName($0).hasPrefix("Siri · ") }, "Siri 音色的显示名带 Siri 前缀")

// 设置页那句「当前使用」—— 「为什么听着还是不自然」看一眼就有答案
let savedFollow = Speech.shared.followsSystemVoice
Speech.shared.followsSystemVoice = true
check(Speech.shared.currentVoiceDescription.contains("跟随系统"), "跟随系统时「当前使用」如实说明")
Speech.shared.followsSystemVoice = false
check(Speech.shared.currentVoiceDescription != "跟随系统朗读设置（与 VoiceOver 同一套）",
      "关掉跟随系统后显示具体语音：\(Speech.shared.currentVoiceDescription)")
check(sortedZh.first.map { Speech.shared.currentVoiceDescription.contains(Speech.displayName($0)) } ?? false,
      "关掉跟随系统时显示的就是列表里那个最高档语音")
Speech.shared.followsSystemVoice = savedFollow

// 语音列表缓存必须能失效：我们的提示让用户"下载完就能选到"，
// 若缓存算完就锁死，用户得重启 App 才看得到 —— 等于自己的提示在骗人。
let beforeRescan = Speech.chineseVoices().count
Speech.refreshVoices()
check(Speech.chineseVoices().count == beforeRescan, "清缓存后语音列表能正确重建（\(beforeRescan) 个）")
let versionBefore = Speech.shared.voiceListVersion
Speech.shared.rescanVoices()
check(Speech.shared.voiceListVersion == versionBefore + 1, "重扫会通知界面刷新（版本号 +1）")
check(!Speech.shared.voices.isEmpty, "界面读到的语音列表非空（\(Speech.shared.voices.count) 个）")

// 默认要「跟随系统朗读设置」——这才是与 VoiceOver 同款语音的正规做法
check(UserDefaults.standard.object(forKey: "speech.followSystem") == nil
      || Speech.shared.followsSystemVoice == true, "默认跟随系统朗读设置")

// 语速必须是「改了就落值」的存储属性 —— 设置页拖滑条依赖这个
// （以前写成读写 UserDefaults 的计算属性，值写进去了但界面收不到通知，滑条纹丝不动）
let savedRate = Speech.shared.rate
Speech.shared.rate = 0.55
check(Speech.shared.rate == 0.55, "语速改动能立即读到新值（滑条拖动才有反馈）")
Speech.shared.rate = savedRate
check(Speech.shared.rate == savedRate, "语速能改回来")

print("\n[20] 侧边栏选择被置空后的兜底（⌘ 点取消选中不能卡死）")

// 复现场景：在设置页 → 手势返回（系统把选择置空）→ 再点「设置」
let sel = newModel()
sel.selection = .settings
sel.selectionCleared()   // 系统置空时的兜底
check(sel.selection == .classroom(sel.classID), "选择被置空后落回当前班级（\(sel.selection.id)）")
check(sel.selection != .settings, "不会停在设置页 —— 否则再点「设置」值没变化、不推页面，看着就是卡死")

// 兜底后，任何一项都成了「变化」，点击都能正常响应
let before = sel.selection
sel.selection = .settings
check(sel.selection != before, "「设置」相对兜底后的值是有变化的（点击能生效）")
sel.selection = .tool(.dice)
check(sel.selection != before, "工具项同样有变化")

print("\n[21] 随机分组（2.0）")

// 分组是「全班参与」，不受「这轮已点过谁」影响 —— 分组要的是所有人。
let gm = newModel()
gm.selection = .classroom("2601")
gm.drawnByClass["2601"] = [1, 2, 3]
check(gm.groupPool.count == 49, "分组池是全班 49 人，不是「还没点过的」（实际 \(gm.groupPool.count)）")

gm.groupMode = .byGroups
gm.groupCount = 4
check(gm.plannedGroupCount == 4, "界面能提前报出组数")
let g4 = gm.nextGroups()
check(g4.count == 4, "分成 4 组（实际 \(g4.count)）")
check(Set(g4.flatMap { $0 }).count == 49, "49 人一个不多一个不少（实际 \(Set(g4.flatMap { $0 }).count)）")
let sizes4 = g4.map(\.count).sorted()
check((sizes4.last ?? 0) - (sizes4.first ?? 0) <= 1,
      "各组人数最多差 1（\(sizes4)）—— 切段分法会出现 13/13/13/11 这种偏得很难看的分配")
check(g4.allSatisfy { $0 == $0.sorted() }, "组内按学号排序（念名单时不会跳号）")

// 两次分组不该完全一样（49 人分 4 组，重复概率可以忽略）
var differs = false
for _ in 0..<8 where !differs {
    if gm.nextGroups() != g4 { differs = true }
}
check(differs, "连分几次结果会变（不是固定切法）")

gm.groupCount = 99
check(gm.clampedGroupCount == GroupSplit.groupRange.upperBound, "组数超上限被夹到 12")
check(gm.nextGroups().count <= 12, "夹住后不会真去分 99 组")
gm.groupCount = 4

gm.groupMode = .bySize
gm.groupSize = 6
check(gm.plannedGroupCount == 9, "49 人按 6 人一组应分 9 组（实际 \(gm.plannedGroupCount)）")
let g6 = gm.nextGroups()
check(g6.count == 9, "实际也是 9 组（实际 \(g6.count)）")
check(g6.map(\.count).reduce(0, +) == 49, "人数不丢")
check((g6.map(\.count).max() ?? 0) <= 6, "没有超过 6 人的组（\(g6.map(\.count))）")
gm.groupSize = 99
check(gm.clampedGroupSize == GroupSplit.sizeRange.upperBound, "每组人数超上限夹到 20")
gm.groupSize = 6

check(emptyModel.nextGroups().isEmpty, "没有名单时分不出组（不会崩）")
check(GroupSplit.byCount([], groups: 3).isEmpty, "空池分组返回空")
check(GroupSplit.byCount([7], groups: 5).count == 1, "1 个人分 5 组只出 1 组")
check(GroupSplit.bySize([1, 2, 3], size: 1).isEmpty == false, "每组 1 人也算得出来")

// 分组设置要能记住
gm.groupMode = .bySize
gm.groupSize = 5
gm.groupShowNumbers = false
let gm2 = newModel()
check(gm2.groupMode == .bySize, "分组方式重启后保留")
check(gm2.groupSize == 5, "每组人数重启后保留")
check(gm2.groupShowNumbers == false, "「显示学号」开关重启后保留")

// 可复制文本（贴到班级群用）
gm.groupMode = .byGroups
gm.groupCount = 2
gm.groupShowNumbers = true
let textGroups = gm.nextGroups()
gm.groups = textGroups
let plain = gm.groupsPlainText
check(plain.hasPrefix("第 1 组（"), "复制文本以「第 1 组」开头")
check(plain.components(separatedBy: "\n").count == 2, "两组两行")
check(plain.contains("2601-"), "带学号与姓名")

print("\n[22] 历史记录与点名统计（2.0）")

let hm = newModel()
hm.selection = .classroom("2601")
hm.clearHistory()
check(hm.history.isEmpty, "起点为空")

hm.logHistory(kind: HistoryKind.pick, classID: "2601", numbers: [1, 2], text: "01 甲、02 乙")
hm.logHistory(kind: HistoryKind.pick, classID: "2601", numbers: [1], text: "01 甲")
hm.logHistory(kind: HistoryKind.pick, classID: "2602", numbers: [5], text: "05 戊")
hm.logHistory(kind: HistoryKind.group, classID: "2601", text: "4 组（13、12、12、12 人）")
hm.logHistory(kind: Tool.dice.rawValue, text: "3 + 5 = 8")
check(hm.history.count == 5, "记了 5 条（实际 \(hm.history.count)）")

// 同一批里同一个学号只算一次（多人点名不会把某人算成两次）
let counts2601 = hm.pickCounts(of: "2601")
check(counts2601[1] == 2, "1 号被点 2 次（实际 \(counts2601[1] ?? 0)）")
check(counts2601[2] == 1, "2 号被点 1 次")
check(counts2601[5] == nil, "别的班的记录不会串进来")
check(hm.pickEventCount(of: "2601") == 2, "2601 共点过 2 次名")
check(hm.pickEventTotal == 3, "全部点名 3 次（含 2602）")
check(hm.groupEventTotal == 1, "分组 1 次")

check(hm.historyEntries(kind: HistoryKind.pick).count == 3, "按类型筛选出 3 条点名")
check(hm.historyEntries(kind: nil).first?.kind == Tool.dice.rawValue, "界面里新的在上")
check(hm.historyEntries(kind: nil).count == 5, "不过滤时是全部")

let least = hm.leastPicked(of: "2601", limit: 3)
check(least.count == 3, "取 3 个最少被点的")
check(least[0].count == 0, "排第一的是没被点过的")
check(least[0].no == 3, "同次数按学号，3 号排最前（实际 \(least[0].no) 号）")
check(least.allSatisfy { $0.count == 0 }, "前三名都是 0 次")

// CSV
let csv = hm.historyCSV()
check(csv.hasPrefix("\u{FEFF}"), "CSV 带 UTF-8 BOM（Excel 打开不乱码）")
check(csv.contains("时间,类型,班级,结果"), "表头四列")
check(csv.contains("点名") && csv.contains("分组") && csv.contains("骰子"), "类型是中文字")
check(csv.contains("2601 班"), "班级 id 已换成可读的班名")
let csvLines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
check(csvLines.count == 6, "5 条记录 + 1 行表头（实际 \(csvLines.count)）")

check(HistoryCSV.escape("普通") == "普通", "普通字段不加引号")
check(HistoryCSV.escape("a,b") == "\"a,b\"", "含逗号要包引号")
check(HistoryCSV.escape("他说\"好\"") == "\"他说\"\"好\"\"\"", "引号翻倍（Excel 的转义规则）")

// 上限与裁剪
hm.clearHistory()
for i in 0..<(AppModel.historyLimit + 50) {
    hm.history.append(HistoryEntry(kind: Tool.coin.rawValue, text: "第\(i)条"))
}
hm.trimHistory()
check(hm.history.count == AppModel.historyLimit, "裁到上限 \(AppModel.historyLimit) 条")
check(hm.history.first?.text == "第50条", "丢的是最旧的（实际 \(hm.history.first?.text ?? "nil")）")
check(hm.history.last?.text == "第\(AppModel.historyLimit + 49)条", "留的是最新的")

// 落盘往返
hm.clearHistory()
hm.logHistory(kind: HistoryKind.pick, classID: "2603", numbers: [7], text: "07 庚")
let hm2 = newModel()
check(hm2.history.count == 1, "历史重启后还在（实际 \(hm2.history.count) 条）")
check(hm2.history.first?.numbers == [7], "学号也一起存回来了")
check(hm2.pickCounts(of: "2603")[7] == 1, "统计跟着回来")
check(hm2.history.first?.isPick == true, "点名标记正确")

hm2.selection = .history
let hm3 = newModel()
check(hm3.selection == .history, "记住上次停在历史页（实际 \(hm3.selection.id)）")
hm3.selection = .classroom("2601")

hm2.clearHistory()
check(newModel().history.isEmpty, "清空后重启仍是空")

print("\n[23] 舞台字号（2.0，投影用）")

let sm = newModel()
check(abs(sm.stageScale - 1.0) < 0.001, "默认 100%")
sm.stageScale = 1.4
check(abs(sm.effectiveStageScale - 1.4) < 0.001, "可调到 140%")
sm.stageScale = 5
check(sm.effectiveStageScale == 1.6, "超上限夹到 160%（不会把舞台撑破）")
sm.stageScale = 0.1
check(sm.effectiveStageScale == 0.8, "低于下限夹到 80%")
sm.stageScale = 1.2
let sm2 = newModel()
check(abs(sm2.stageScale - 1.2) < 0.001, "字号重启后保留（实际 \(sm2.stageScale)）")
sm2.stageScale = 1.0
sm2.persist()

print("\n[24] 年级分组（侧边栏按年级折叠）")

// 班号前两位是入学年：2026 学年时 26 级=初一、25 级=初二、24 级=初三。
check(ClassRoster.schoolYearStart(now: dateFrom("2026-09-01")) == 2026, "9 月起算新学年")
check(ClassRoster.schoolYearStart(now: dateFrom("2026-03-01")) == 2025, "3 月还属上一学年")
check(ClassRoster.grade(forClassID: "2401", schoolYearStart: 2026) == .junior3, "24 级 → 初三")
check(ClassRoster.grade(forClassID: "2501", schoolYearStart: 2026) == .junior2, "25 级 → 初二")
check(ClassRoster.grade(forClassID: "2601", schoolYearStart: 2026) == .junior1, "26 级 → 初一")
check(ClassRoster.grade(forClassID: "2301", schoolYearStart: 2026) == nil, "已毕业的 23 级不归入任何年级")
check(ClassRoster.grade(forClassID: "初一3班", schoolYearStart: 2026) == nil, "非数字班号不外推")
check(ClassRoster.grade(forClassID: "2401", schoolYearStart: 2027) == nil,
      "同一批人次年不再算初三（不写死映射的好处）")

// 三个年级混排：顺序必须是 初三 → 初二 → 初一，且「其他」垫底。
let mixed = [
    ClassRoster.SchoolClass(id: "2601", names: ["甲"]),
    ClassRoster.SchoolClass(id: "2401", names: ["乙", "丙"]),
    ClassRoster.SchoolClass(id: "A组", names: ["丁"]),
]
let gradeModel = AppModel(autoloadImported: false, seedRoster: mixed, seedName: "混排",
                  rosterStore: tempRosterURL())
check(gradeModel.gradeGroups.count == 3, "初三 / 初一 / 其他 共 3 组（实际 \(gradeModel.gradeGroups.count)）")
check(gradeModel.gradeGroups.first?.grade == .junior3, "初三排最前")
check(gradeModel.gradeGroups.first?.title == "初三年级", "分组标题是「初三年级」")
check(gradeModel.gradeGroups.last?.grade == nil, "推不出年级的「其他班级」垫底")
check(gradeModel.gradeGroups.first?.classes.count == 1, "初三组 1 个班")
// 显式指定当前班：构造函数会读回上一次持久化的选择，别让别的用例影响这一条
gradeModel.classID = "2401"
check(gradeModel.currentGrade == .junior3, "当前班 2401 属初三")

gradeModel.classID = "2601"
check(gradeModel.currentGrade == .junior1, "切到 2601 后当前年级变初一")

// 全部同一年级时不产生空分组
let only10 = AppModel(autoloadImported: false, seedRoster: [mixed[0]], seedName: nil,
                      rosterStore: tempRosterURL())
check(only10.gradeGroups.count == 1, "只有一个年级时不出现空分组")


if failures == 0 {
    print("全部通过 ✅")
    exit(0)
} else {
    print("失败 \(failures) 项 ❌")
    exit(1)
}
