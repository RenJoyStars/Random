import SwiftUI
import Observation

// MARK: - 侧边栏条目
// 班级按班拆成若干独立入口（来自导入的名单），随机工具并列另一组。

enum SidebarItem: Hashable, Identifiable {
    case classroom(String)   // 班号，如 "2601"
    case tool(Tool)
    case history             // 统一时间线：点名 / 分组 / 各工具
    case settings            // iOS 没有独立的设置窗口，用一栏承载

    var id: String {
        switch self {
        case .classroom(let c): return "class-\(c)"
        case .tool(let t):      return "tool-\(t.rawValue)"
        case .history:          return "history"
        case .settings:         return "settings"
        }
    }

    var classroomID: String? {
        if case .classroom(let c) = self { return c }
        return nil
    }
}

// MARK: - 随机工具

enum Tool: String, CaseIterable, Identifiable, Hashable {
    // 分组排在第一个：它是「课堂活动」的起点，和后面八个「随手抽个结果」不是一类。
    case grouping, sequence, randomNumber, dice, coin, card, color, letter, rockPaperScissors, yesNo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grouping:          return "随机分组"
        case .sequence:          return "随机顺序"
        case .randomNumber:      return "随机数字"
        case .dice:              return "骰子"
        case .coin:              return "硬币"
        case .card:              return "抽卡"
        case .color:             return "随机颜色"
        case .letter:            return "随机字母"
        case .rockPaperScissors: return "剪刀石头布"
        case .yesNo:             return "是或否"
        }
    }

    var symbol: String {
        switch self {
        case .grouping:          return "person.3.sequence"
        case .sequence:          return "list.number"
        case .randomNumber:      return "arrow.left.arrow.right"
        case .dice:              return "die.face.6"
        case .coin:              return "circle.lefthalf.filled"
        case .card:              return "suit.spade.fill"
        case .color:             return "paintpalette.fill"
        case .letter:            return "a.square"   // 不用 textformat：中文下会渲染成「格式」
        case .rockPaperScissors: return "hand.raised.fill"
        case .yesNo:             return "questionmark.circle"
        }
    }

    var actionTitle: String {
        switch self {
        case .grouping:          return "分组"
        case .sequence:          return "打乱"
        case .dice:              return "掷骰子"
        case .coin:              return "抛硬币"
        case .card:              return "抽一张"
        case .rockPaperScissors: return "出拳"
        default:                 return "抽取"
        }
    }
}

// MARK: - 落定特效主题
//
// 定义放在这里（而不是 DesignKit.swift）是有意的：它是纯数据，
// 不依赖 SwiftUI，无头自测就能直接验证「每次随机」到底随不随机。

/// 落定特效强度。投影仪和教室里那台老 Mac 上，24 种粒子全开有时会掉帧；
/// 老师要的是「抽完看得见」，不是「动画必须满配」，所以给三档。
enum EffectLevel: String, CaseIterable, Identifiable, Sendable {
    case full, lite, off

    var id: String { rawValue }
    var title: String {
        switch self {
        case .full: return "完整"
        case .lite: return "精简（约一半粒子）"
        case .off:  return "关闭"
        }
    }
    /// 粒子密度系数
    var density: Double {
        switch self {
        case .full: return 1.0
        case .lite: return 0.45
        case .off:  return 0
        }
    }
}

enum CelebrationTheme: String, CaseIterable, Identifiable, Sendable {

    // 经典：礼炮 / 烟花 / 星芒 / 光环
    case confetti, fireworks, starburst, rings
    // 飘落：从上往下，或轻飘飘地飞
    case paperRain, snow, petals, leaves, goldRain, butterflies
    // 涌动：从下往上 / 绕圈
    case hearts, bubbles, fountain, spiral, vortex
    // 光效：细长的光、闪的东西
    case starfall, neonStreaks, glitter, coins, comet
    // 爆发：一声闷响炸开
    case nova, shockwave, pixels, salvo

    var id: String { rawValue }

    /// 五个族。设置页按族分组（24 个平铺一列没法看）。
    enum Family: String, CaseIterable, Identifiable, Sendable {
        case classic, falling, rising, light, blast

        var id: String { rawValue }

        var title: String {
            switch self {
            case .classic: return "经典"
            case .falling: return "飘落"
            case .rising:  return "涌动"
            case .light:   return "光效"
            case .blast:   return "爆发"
            }
        }

        var themes: [CelebrationTheme] { CelebrationTheme.allCases.filter { $0.family == self } }
    }

    var family: Family {
        switch self {
        case .confetti, .fireworks, .starburst, .rings:
            return .classic
        case .paperRain, .snow, .petals, .leaves, .goldRain, .butterflies:
            return .falling
        case .hearts, .bubbles, .fountain, .spiral, .vortex:
            return .rising
        case .starfall, .neonStreaks, .glitter, .coins, .comet:
            return .light
        case .nova, .shockwave, .pixels, .salvo:
            return .blast
        }
    }

    var title: String {
        switch self {
        case .confetti:     return "彩带礼炮"
        case .fireworks:    return "连环烟花"
        case .starburst:    return "星芒绽放"
        case .rings:        return "冲击光环"
        case .paperRain:    return "纸片雨"
        case .snow:         return "雪花飘落"
        case .petals:       return "花瓣纷飞"
        case .leaves:       return "秋叶飘零"
        case .goldRain:     return "金雨"
        case .butterflies:  return "蝴蝶飞舞"
        case .hearts:       return "爱心升起"
        case .bubbles:      return "气泡上浮"
        case .fountain:     return "喷泉"
        case .spiral:       return "螺旋喷发"
        case .vortex:       return "漩涡"
        case .starfall:     return "流星雨"
        case .neonStreaks:  return "霓虹光条"
        case .glitter:      return "闪粉"
        case .coins:        return "金币雨"
        case .comet:        return "彗星"
        case .nova:         return "新星爆发"
        case .shockwave:    return "冲击波"
        case .pixels:       return "像素爆裂"
        case .salvo:        return "礼花齐放"
        }
    }

    var symbol: String {
        switch self {
        case .confetti:     return "party.popper.fill"
        case .fireworks:    return "sparkles"
        case .starburst:    return "star.circle.fill"
        case .rings:        return "circle.dashed"
        case .paperRain:    return "doc.fill"
        case .snow:         return "snowflake"
        case .petals:       return "leaf.fill"
        case .leaves:       return "wind"
        case .goldRain:     return "cloud.rain.fill"
        case .butterflies:  return "ant.fill"
        case .hearts:       return "heart.fill"
        case .bubbles:      return "circle.hexagongrid.fill"
        case .fountain:     return "arrow.up.circle.fill"
        case .spiral:       return "tornado"
        case .vortex:       return "hurricane"
        case .starfall:     return "sparkle"
        case .neonStreaks:  return "light.beacon.max.fill"
        case .glitter:      return "wand.and.stars"
        case .coins:        return "dollarsign.circle.fill"
        case .comet:        return "moon.stars.fill"
        case .nova:         return "sun.max.fill"
        case .shockwave:    return "wave.3.right"
        case .pixels:       return "square.grid.3x3.fill"
        case .salvo:        return "fireworks"
        }
    }

    /// 设置页「随机」的键值。`resolve` 遇到它就现场抽一个。
    static let randomKey = "random"

    /// 把设置里存的字符串解析成主题；不认识的（含 random）一律现场随机。
    static func resolve(_ key: String) -> CelebrationTheme {
        if key != randomKey, let t = CelebrationTheme(rawValue: key) { return t }
        return allCases.randomElement() ?? .confetti
    }

    /// 这个主题演多久（秒）。飘落类要久一点才飘得完，爆发类收得快。
    var duration: Double {
        switch self {
        case .confetti:     return 2.3
        case .fireworks:    return 2.4
        case .starburst:    return 1.7
        case .rings:        return 1.9
        case .paperRain:    return 2.8
        case .snow:         return 3.2
        case .petals:       return 3.0
        case .leaves:       return 3.0
        case .goldRain:     return 2.4
        case .butterflies:  return 3.0
        case .hearts:       return 2.6
        case .bubbles:      return 2.8
        case .fountain:     return 2.2
        case .spiral:       return 1.9
        case .vortex:       return 2.0
        case .starfall:     return 2.0
        case .neonStreaks:  return 1.6
        case .glitter:      return 2.0
        case .coins:        return 2.4
        case .comet:        return 1.8
        case .nova:         return 2.0
        case .shockwave:    return 1.5
        case .pixels:       return 1.7
        case .salvo:        return 2.3
        }
    }
}

// MARK: - 扑克牌

struct PlayingCard: Hashable, Identifiable {
    enum Suit: String, CaseIterable, Hashable {
        case spade, heart, diamond, club

        var symbol: String {
            switch self {
            case .spade:   return "suit.spade.fill"
            case .heart:   return "suit.heart.fill"
            case .diamond: return "suit.diamond.fill"
            case .club:    return "suit.club.fill"
            }
        }
        var isRed: Bool { self == .heart || self == .diamond }
        var label: String {
            switch self {
            case .spade:   return "黑桃"
            case .heart:   return "红心"
            case .diamond: return "方块"
            case .club:    return "梅花"
            }
        }
    }

    var rank: String
    var suit: Suit?
    var id: String { suit.map { "\($0.rawValue)-\(rank)" } ?? rank }
    var isJoker: Bool { suit == nil }

    /// 给人看的牌面（「黑桃A」），界面与历史记录里都用它
    var displayName: String { isJoker ? rank : "\(suit?.label ?? "")\(rank)" }

    static func fullDeck(includeJokers: Bool) -> [PlayingCard] {
        let ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
        var deck: [PlayingCard] = []
        for suit in Suit.allCases {
            for rank in ranks { deck.append(PlayingCard(rank: rank, suit: suit)) }
        }
        if includeJokers {
            deck.append(PlayingCard(rank: "小王", suit: nil))
            deck.append(PlayingCard(rank: "大王", suit: nil))
        }
        return deck
    }
}

// MARK: - 枚举

enum ColorPaletteMode: String, CaseIterable, Identifiable {
    case full, bright, pastel, deep
    var id: String { rawValue }
    var title: String {
        switch self {
        case .full:   return "全随机"
        case .bright: return "明亮"
        case .pastel: return "柔和"
        case .deep:   return "深色"
        }
    }
}

enum LetterScope: String, CaseIterable, Identifiable {
    case full, firstEight, vowels
    var id: String { rawValue }
    var title: String {
        switch self {
        case .full:       return "A–Z"
        case .firstEight: return "A–H"
        case .vowels:     return "元音"
        }
    }
    var letters: [String] {
        switch self {
        case .full:       return (65...90).map { String(UnicodeScalar($0)!) }
        case .firstEight: return (65...72).map { String(UnicodeScalar($0)!) }
        case .vowels:     return ["A", "E", "I", "O", "U"]
        }
    }
}

enum RPS: String, CaseIterable, Identifiable {
    case rock, scissors, paper
    var id: String { rawValue }
    var title: String {
        switch self {
        case .rock:     return "石头"
        case .scissors: return "剪刀"
        case .paper:    return "布"
        }
    }
    var glyph: String {
        switch self {
        case .rock:     return "✊"
        case .scissors: return "✌️"
        case .paper:    return "✋"
        }
    }
    /// 1 = self 赢，-1 = self 输，0 = 平
    func versus(_ other: RPS) -> Int {
        if self == other { return 0 }
        switch (self, other) {
        case (.rock, .scissors), (.scissors, .paper), (.paper, .rock): return 1
        default: return -1
        }
    }
}

// MARK: - 应用状态

@Observable
final class AppModel {

    // MARK: 导航

    /// 默认落在「班级」分组上。还没导入名单时 classID 是空串，
    /// 界面据此显示「先导入名单」的空状态（见 RootView 的 NoRosterView）。
    var selection: SidebarItem = .classroom("") {
        didSet {
            if case .classroom(let c) = selection { classID = c }
            pickResults = []
            lastDrawn = []
            groups = []          // 分组结果是「某个班的」，切走就不该再显示
            pickMessage = Self.idleMessage
            persist()
        }
    }

    /// 未开抽时的提示语（放在模型里，别散落在各处）。
    static var idleMessage: String { "按「点名」或 ⌘↩ 开始" }

    /// 当前班级号（点名页的数据均绑定于此）。空串 = 还没导入名单。
    var classID: String = ""
    var rosterOverrides: [String: [String]] = [:]

    /// 当前生效的班级列表。
    ///
    /// **初始为空** —— 应用不再内置任何名单，第一次使用必须导入自己的
    /// `.randomroster`，之后会自动记住。侧边栏、班级菜单、点名记录都从这里取。
    var activeClasses: [ClassRoster.SchoolClass] = ClassRoster.empty

    /// 是否已经导入过名单（决定界面显示空状态还是班级列表）。
    var hasClasses: Bool { !activeClasses.isEmpty }

    /// 导入名单的总标题（文件里的 name 字段），用于设置页展示。
    var importedRosterName: String? = nil

    var currentClass: ClassRoster.SchoolClass {
        activeClasses.first { $0.id == classID }
            ?? ClassRoster.SchoolClass(id: classID.isEmpty ? "—" : classID, names: [])
    }

    var currentNames: [String] {
        if let o = rosterOverrides[classID], !o.isEmpty { return o }
        return activeClasses.first { $0.id == classID }?.names ?? []
    }

    var classCount: Int { currentNames.count }

    func name(no: Int) -> String? {
        let list = currentNames
        let i = no - 1
        guard i >= 0, i < list.count else { return nil }
        return list[i]
    }

    func names(of classID: String) -> [String] {
        if let o = rosterOverrides[classID], !o.isEmpty { return o }
        return activeClasses.first(where: { $0.id == classID })?.names ?? []
    }

    /// 班级显示名（导航栏标题用）。找不到就退回班号本身。
    func title(of classID: String) -> String {
        activeClasses.first(where: { $0.id == classID })?.title ?? "班级"
    }

    func drawnCount(of classID: String) -> Int {
        Set(drawnByClass[classID] ?? []).count
    }

    // MARK: 年级分组

    /// 侧边栏的分组：按年级从高到低（初三 → 初二 → 初一），
    /// 推不出年级的外部名单统一落在最后一组。
    ///
    /// 18 个班平铺在侧边栏里要占满一整屏、天天靠滚 —— 分组后默认只展开
    /// 当前在用的那个年级，其余收起来。
    struct GradeGroup: Identifiable {
        let grade: ClassRoster.Grade?
        var classes: [ClassRoster.SchoolClass]

        var id: String { grade.map { "g\($0.rawValue)" } ?? "other" }
        var title: String { grade?.groupTitle ?? "其他班级" }
        var count: Int { classes.count }
    }

    var gradeGroups: [GradeGroup] {
        var byGrade: [ClassRoster.Grade: [ClassRoster.SchoolClass]] = [:]
        var other: [ClassRoster.SchoolClass] = []
        for c in activeClasses {
            if let g = c.grade { byGrade[g, default: []].append(c) } else { other.append(c) }
        }
        var out = ClassRoster.Grade.allCases.sorted(by: >).compactMap { g -> GradeGroup? in
            guard let list = byGrade[g], !list.isEmpty else { return nil }
            return GradeGroup(grade: g, classes: list)
        }
        if !other.isEmpty { out.append(GradeGroup(grade: nil, classes: other)) }
        return out
    }

    /// 当前班所在的年级（侧边栏默认展开它）。
    var currentGrade: ClassRoster.Grade? {
        activeClasses.first { $0.id == classID }?.grade
    }

    /// 只切「当前班」，不离开当前页面（随机分组页用）。
    ///
    /// 走 `selection` 会直接跳到班级页，而分组页 / 顺序页需要在原地换班；
    /// 但换班后残留的分组、顺序、点名结果属于上一个班，必须一起清掉 ——
    /// 否则屏幕上会挂着一份「上一个班的第 1 位是某某」，而这个名字根本不在当前班里。
    func switchClass(_ id: String) {
        guard activeClasses.contains(where: { $0.id == id }) else { return }
        classID = id
        groups = []
        sequenceResult = []
        pickResults = []
        lastDrawn = []
        pickMessage = Self.idleMessage
        if case .classroom = selection { selection = .classroom(id) }
        persist()
    }

    // MARK: 班级（每班独立记录）

    var padZero: Bool = true
    var noRepeat: Bool = true

    /// 每次点名同时抽几个人
    var pickCount: Int = 1
    var effectivePickCount: Int { min(max(1, pickCount), 10) }

    /// 音效开关（默认开）。关掉后连音频引擎都不会被创建。
    var soundOn: Bool = true {
        didSet {
            Sound.enabled = soundOn
            persist()
        }
    }

    /// 舞台字号倍数（2.0）：只放大「结果」本身，不动界面其余部分。
    ///
    /// 投影到教室大屏时，老师要的是后排也看得清那个学号 / 姓名；
    /// 整窗缩放会把侧边栏和按钮一起放大，屏幕上反而更挤。所以只缩放结果。
    var stageScale: Double = 1.0 {
        didSet { persist() }
    }

    /// 夹到合法区间（滑条以外的入口，比如将来的快捷键，也不会越界）
    var effectiveStageScale: Double { min(max(stageScale, 0.8), 1.6) }

    var pickResults: [Int] = []
    var pickRolling: Bool = false
    var pickMessage: String = AppModel.idleMessage
    var drawnByClass: [String: [Int]] = [:]
    var lastDrawn: [Int] = []

    /// 落定计数：点名 / 抽取落定时 +1，界面据此放一次彩带。属于瞬时状态，不持久化。
    var celebration: Int = 0

    // MARK: 历史记录（2.0）
    //
    // 一条时间线装下所有结果。历史落盘在独立的 key（JSON Data），
    // 不塞进 state 字典里 —— 两千条记录塞字典会让每次 persist 都重编码一大坨。

    /// 最多留多少条。一门课一学期大约几百次，2000 条够两三年。
    static let historyLimit = 2000

    var history: [HistoryEntry] = []

    /// 记一条历史。空结果不记（避免切页 / 空点留一堆噪声）。
    func logHistory(kind: String, classID: String = "", numbers: [Int] = [],
                    text: String, at date: Date = Date()) {
        guard !text.isEmpty else { return }
        history.append(HistoryEntry(date: date, kind: kind, classID: classID,
                                    numbers: numbers, text: text))
        trimHistory()
        persistHistory()
    }

    /// 超出上限时丢最旧的。抽成独立方法是为了自测能直接验证，不用真的写 2000 次盘。
    func trimHistory() {
        guard history.count > Self.historyLimit else { return }
        history.removeFirst(history.count - Self.historyLimit)
    }

    /// 某班每个人的被点次数（按历史统计；同一批里重复的学号只算一次）。
    func pickCounts(of classID: String) -> [Int: Int] {
        var out: [Int: Int] = [:]
        for e in history where e.isPick && e.classID == classID {
            for no in Set(e.numbers) { out[no, default: 0] += 1 }
        }
        return out
    }

    /// 某班总共点过多少次名
    func pickEventCount(of classID: String) -> Int {
        history.reduce(0) { $0 + (($1.isPick && $1.classID == classID) ? 1 : 0) }
    }

    /// 全部点名次数 / 分组次数（历史页概览用）
    var pickEventTotal: Int { history.reduce(0) { $0 + ($1.isPick ? 1 : 0) } }
    var groupEventTotal: Int { history.reduce(0) { $0 + ($1.kind == HistoryKind.group ? 1 : 0) } }

    /// 被点次数最少的几个人（次数相同按学号）。
    ///
    /// 用途很实在：一学期下来如果总是那几个人被点，这里一眼就能看出来。
    func leastPicked(of classID: String, limit: Int = 6) -> [PickStatEntry] {
        let counts = pickCounts(of: classID)
        var all: [PickStatEntry] = []
        for (i, name) in names(of: classID).enumerated() {
            let no = i + 1
            all.append(PickStatEntry(no: no, name: name, count: counts[no] ?? 0))
        }
        all.sort { lhs, rhs in
            lhs.count == rhs.count ? lhs.no < rhs.no : lhs.count < rhs.count
        }
        return Array(all.prefix(max(0, limit)))
    }

    /// 按类型筛选历史；`nil` = 全部。界面里新的在上。
    func historyEntries(kind: String?) -> [HistoryEntry] {
        let all = kind.map { k in history.filter { $0.kind == k } } ?? history
        return Array(all.reversed())
    }

    /// 导出用的 CSV（表头 + 全部记录，新的在上）
    func historyCSV() -> String {
        HistoryCSV.make(Array(history.reversed())) { [weak self] id in
            self?.title(of: id) ?? id
        }
    }

    func clearHistory() {
        history = []
        persistHistory()
    }

    // MARK: 落定特效 / 音效风格
    //
    // 「每次不一样」是刻意的：同一套彩带看一学期，学生第三节课就腻了。

    /// 特效风格：`random` 或 `CelebrationTheme.rawValue`
    var celebrationStyle: String = CelebrationTheme.randomKey {
        didSet { persist() }
    }

    /// 落定特效强度：完整 / 精简 / 关闭
    var effectLevel: EffectLevel = .full { didSet { persist() } }

    /// 音效风格：`random` 或 `SoundTheme.rawValue`
    var soundStyle: String = SoundTheme.randomKey {
        didSet {
            Sound.themeStyle = SoundTheme.resolve(soundStyle)
            persist()
        }
    }

    /// 抽取节奏倍率。1.0 = 标准（约 1 秒），小于 1 更快、大于 1 更慢。
    ///
    /// 只在这一处乘：8 种工具的抽取都走 `finishAfter`，
    /// 乘一次就全都跟着变 —— 不用每个工具各配一个滑块。
    var pickSpeed: Double = 1.0 {
        didSet { persist() }
    }

    /// 实际生效的倍率。0.5 倍时约半秒，再快就只剩"闪一下"，学生看不清；
    /// 1.8 倍已经接近两秒，再慢会拖堂。
    var effectivePickSpeed: Double { min(max(pickSpeed, 0.5), 1.8) }

    /// 音效音量 0…1。投影教室里 0.8 是「后排听得见、前排不炸耳」。
    var soundVolume: Double = 0.8 {
        didSet {
            Sound.volume = Float(min(max(soundVolume, 0), 1))
            persist()
        }
    }

    /// 本次落定实际用的特效主题。视图读它来画 —— 每个 cheer() 重新抽一次。
    var celebrationTheme: CelebrationTheme = .confetti

    /// 放一次落定特效：先按设置挑主题，再加一触发视图。
    ///
    /// 所有落定点（点名与八种工具的抽取）都走这里，
    /// 免得哪一处忘了更新主题、画出来的还是上一次的。
    func cheer() {
        celebrationTheme = CelebrationTheme.resolve(celebrationStyle)
        celebration += 1
    }

    var drawn: [Int] { drawnByClass[classID] ?? [] }
    var pickTotal: Int { classCount }
    var pickRemaining: Int {
        guard noRepeat else { return pickTotal }
        return max(0, pickTotal - Set(drawn).count)
    }
    var canUndo: Bool { !lastDrawn.isEmpty }

    func fmtNo(_ n: Int) -> String {
        padZero ? String(format: "%02d", n) : String(n)
    }

    /// 本次抽中的姓名（名单里没有对应项时自动跳过）
    var pickedNames: [String] { pickResults.compactMap { name(no: $0) } }

    /// 可抽号码池（不重复模式下排除本轮已抽过的）。没导入名单时是空的。
    var pickPool: [Int] {
        guard classCount > 0 else { return [] }
        let all = Array(1...classCount)
        guard noRepeat else { return all }
        let used = Set(drawn)
        return all.filter { !used.contains($0) }
    }

    /// 点名完成后的播报：「有请 张三 同学（07 号）」
    func announcement(for numbers: [Int]) -> String {
        guard !numbers.isEmpty else { return "" }
        let nos = numbers.map { fmtNo($0) }.joined(separator: "、")
        let names = numbers.compactMap { name(no: $0) }
        if names.count == numbers.count {
            return "有请 \(names.joined(separator: "、")) 同学（\(nos) 号）"
        }
        return "有请 \(nos) 号同学"
    }

    func drawPick() {
        guard !pickRolling else { return }
        guard hasClasses else {
            pickResults = []
            pickMessage = "还没有班级名单，请先导入"
            return
        }
        let pool = pickPool
        guard !pool.isEmpty else {
            pickResults = []
            pickMessage = "\(currentClass.shortTitle) 班都点过了，清空记录可重新开始"
            return
        }
        let want = min(effectivePickCount, 10)
        let take = min(want, pool.count)
        let final = sample(pool, take).sorted()
        let hi = max(1, classCount)

        pickRolling = true
        finishAfter(2.0, tick: 0.118, tickEnd: 0.042, sound: .pick, roll: {
            self.pickResults = self.sample(Array(1...hi), min(take, hi)).sorted()
        }, settle: {
            Sound.shared.victory()
            self.pickRolling = false
            self.pickResults = final
            if self.noRepeat {
                var cur = self.drawnByClass[self.classID] ?? []
                for n in final where !cur.contains(n) { cur.append(n) }
                self.drawnByClass[self.classID] = cur
                self.lastDrawn = final
            }
            var msg = self.announcement(for: final)
            if take < want { msg += "（本轮只剩 \(take) 个）" }
            self.pickMessage = msg
            self.cheer()
            self.persist()

            // 历史时间线。存学号（统计用）+ 当时看到的文案（回看用）。
            let names = final.compactMap { self.name(no: $0) }
            let nums = final.map { self.fmtNo($0) }.joined(separator: "、")
            self.logHistory(kind: HistoryKind.pick, classID: self.classID,
                            numbers: final,
                            text: names.isEmpty ? nums : "\(nums) \(names.joined(separator: "、"))")

            // 念出姓名。等钟声落下去一点再开口，不然和钟声叠在一起听不清。
            let picked = names
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Speech.shared.announce(picked)
            }
        })
    }

    func undoPick() {
        guard !lastDrawn.isEmpty else { return }
        var cur = drawnByClass[classID] ?? []
        cur.removeAll { lastDrawn.contains($0) }
        drawnByClass[classID] = cur
        lastDrawn = []
        pickResults = []
        pickMessage = "已撤销上一次"
        persist()
    }

    func resetPick() {
        drawnByClass[classID] = []
        lastDrawn = []
        pickResults = []
        pickMessage = Self.idleMessage
        persist()
    }

    func release(_ no: Int) {
        var cur = drawnByClass[classID] ?? []
        cur.removeAll { $0 == no }
        drawnByClass[classID] = cur
        persist()
    }

    // MARK: 随机分组（2.0）

    /// 分组方式：按组数 / 按每组人数
    var groupMode: GroupMode = .byGroups {
        didSet { persist() }
    }

    /// 按组数分时的组数
    var groupCount: Int = 4 {
        didSet { persist() }
    }

    /// 按人数分时每组几个人
    var groupSize: Int = 6 {
        didSet { persist() }
    }

    /// 结果显示里带不带学号（低年级可能只要姓名）
    var groupShowNumbers: Bool = true {
        didSet { persist() }
    }

    /// 本次分组结果（每组一串学号）
    var groups: [[Int]] = []
    var groupingRolling: Bool = false

    var clampedGroupCount: Int {
        min(max(groupCount, GroupSplit.groupRange.lowerBound), GroupSplit.groupRange.upperBound)
    }

    var clampedGroupSize: Int {
        min(max(groupSize, GroupSplit.sizeRange.lowerBound), GroupSplit.sizeRange.upperBound)
    }

    /// 分组的号码池：全班，不受「已点名」影响 ——
    /// 分组要的是「班上所有人」，不是「这一轮还没点过的人」。
    var groupPool: [Int] {
        classCount > 0 ? Array(1...classCount) : []
    }

    /// 本次会分成几组（界面提前告知，不用点了才知道）
    var plannedGroupCount: Int {
        let n = groupPool.count
        guard n > 0 else { return 0 }
        switch groupMode {
        case .byGroups: return min(clampedGroupCount, n)
        case .bySize:   return max(1, Int((Double(n) / Double(clampedGroupSize)).rounded(.up)))
        }
    }

    /// 纯函数：按当前设置算一次分组，不改状态（自测直接调）。
    func nextGroups() -> [[Int]] {
        let pool = groupPool
        guard !pool.isEmpty else { return [] }
        switch groupMode {
        case .byGroups: return GroupSplit.byCount(pool, groups: clampedGroupCount)
        case .bySize:   return GroupSplit.bySize(pool, size: clampedGroupSize)
        }
    }

    /// 分组结果的可复制文本
    var groupsPlainText: String {
        GroupSplit.plainText(groups,
                             names: { self.name(no: $0) },
                             showNumbers: groupShowNumbers,
                             formatNo: { self.fmtNo($0) })
    }

    func copyGroups() {
        let text = groupsPlainText
        guard !text.isEmpty else { return }
        Pasteboard.copy(text)
    }

    func drawGroups() {
        guard !groupingRolling else { return }
        let final = nextGroups()
        guard !final.isEmpty else {
            groups = []
            return
        }

        groupingRolling = true
        finishAfter(1.15, tick: 0.10, tickEnd: 0.05, sound: .shuffle, roll: {
            // 滚动过程也真的在分组，停下来之前看到的是「正在重新洗牌」
            self.groups = self.nextGroups()
        }, settle: {
            Sound.shared.victory()
            self.groupingRolling = false
            self.groups = final
            self.cheer()
            self.logHistory(kind: HistoryKind.group,
                            classID: self.classID,
                            text: "\(final.count) 组（\(GroupSplit.sizeSummary(final)) 人）")
        })
    }

    func resetGroups() {
        groups = []
    }

    // MARK: 随机数字

    var numMin: Int = 1
    var numMax: Int = 100
    var numCount: Int = 1
    /// 同一批里不出现重复号码（抽 5 个就是 5 个不同的数）。
    var numUnique: Bool = true

    /// **跨批次**不重复：抽过的号码，本轮不再抽。
    ///
    /// ⚠️ 这是 2026-10-21 补的。原来的 `numUnique` 只管「这一次抽多个之间不重复」，
    /// 完全没有跨次记忆 —— 老师拿它当「1–49 抽学号」用时，抽过的号码下一次照样会中，
    /// 连续抽十几次几乎必然撞人。课上一旦撞了就得重抽，观感很差。
    /// 默认开启：这个工具在教学里主要就是当抽号器用；想真随机（掷数游戏）再关掉。
    var numNoRepeat: Bool = true

    /// 本轮已抽过的号码（`numNoRepeat` 的池子）
    var numDrawn: [Int] = []
    var numResults: [Int] = []
    var numRolling: Bool = false

    var numLo: Int { min(numMin, numMax) }
    var numHi: Int { max(numMin, numMax) }
    var numRangeSize: Int { max(0, numHi - numLo + 1) }

    /// 可抽号码池。范围改过之后旧记录可能落在范围外 —— 这里按范围过滤，
    /// 不用清空记录也不会抽到越界的数。
    var numPool: [Int] {
        guard numRangeSize > 0 else { return [] }
        let all = Array(numLo...numHi)
        guard numNoRepeat else { return all }
        let used = Set(numDrawn)
        return all.filter { !used.contains($0) }
    }

    /// 本轮还能抽几个不重复的（关闭记忆时就是范围大小）
    var numRemaining: Int { numNoRepeat ? numPool.count : numRangeSize }
    var numPoolEmpty: Bool { numNoRepeat && numPool.isEmpty }

    /// 清空「抽过的不再抽」的记录，重新开一轮
    func resetNumbers() {
        numDrawn = []
        numResults = []
        persist()
    }

    // MARK: 骰子

    var diceCount: Int = 2
    var diceFaces: Int = 6
    var diceValues: [Int] = [1, 1]
    var diceRolling: Bool = false
    var diceSum: Int { diceValues.reduce(0, +) }

    // MARK: 硬币

    var coinIsHeads: Bool?
    var coinHeads: Int = 0
    var coinTails: Int = 0
    var coinRolling: Bool = false

    // MARK: 抽卡

    var includeJokers: Bool = false
    var cardDrawCount: Int = 1
    var cards: [PlayingCard] = []
    var cardRolling: Bool = false

    // MARK: 随机颜色

    var paletteMode: ColorPaletteMode = .bright
    var colorHue: Double = 214
    var colorSat: Double = 0.82
    var colorBri: Double = 1.0
    var colorRolling: Bool = false
    var colorHex: String = "#2F6BFF"
    var red: Double = 0.184
    var green: Double = 0.420
    var blue: Double = 1.0
    var copied: Bool = false

    // MARK: 随机字母

    var letterScope: LetterScope = .full
    var letterUppercase: Bool = true
    var letterResult: String = ""
    var letterRolling: Bool = false

    // MARK: 剪刀石头布

    var myMove: RPS?
    var aiMove: RPS?
    var rpsRolling: Bool = false
    var rpsWins: Int = 0
    var rpsLosses: Int = 0
    var rpsDraws: Int = 0

    // MARK: 是或否

    var yesNoResult: Bool?
    var yesNoRolling: Bool = false
    var yesCount: Int = 0
    var noCount: Int = 0

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let storageKey = "cn.renqiaoyi.random.state.v3"
    /// 启动加载中：这段时间禁止 persist（否则会用默认值覆盖磁盘上的记录）
    @ObservationIgnored private var isLoading = false

    /// 名单落盘位置的可注入覆盖。
    ///
    /// ⚠️ 存在的理由（真出过事）：自测与离屏渲染都会构造 AppModel，
    /// 而默认的名单路径指向**用户真实数据**（App Support 下）。
    /// 此前自测里那条「远端名单下发」直接调 `saveImportedRoster`，
    /// 把老师 18 个班的真实名单覆盖成了测试用的「甲/乙/丙」。
    /// 现在测试必须传 `rosterStore:` 指向临时目录，别碰真实文件。
    @ObservationIgnored private let rosterStoreOverride: URL?

    /// app 全局唯一实例。
    ///
    /// ⚠️ 为什么必须单例：`@State private var model = AppModel()` 里那个默认值表达式
    /// **每次 App 结构体初始化都会被求值**（SwiftUI 会反复重建 App）。于是会凭空造出
    /// 一个又一个 AppModel，状态各自为政 —— 界面上看到的是 A 实例、真正被操作的是 B 实例，
    /// 表现就是「点了没反应」「记录莫名回退」。定成单例才只有一份真相。
    ///
    /// 自测仍然用 `AppModel(...)` 造独立实例，所以 init 保持可用。
    static let shared = AppModel()

    /// - Parameters:
    ///   - autoloadImported: 是否读取本机已导入的名单。自测传 `false`，避免被真机状态污染。
    ///   - seedRoster: 直接指定初始名单（自测造数据用）。给了它就不再读磁盘。
    init(autoloadImported: Bool = true, seedRoster: [ClassRoster.SchoolClass]? = nil,
         seedName: String? = nil, rosterStore: URL? = nil) {
        rosterStoreOverride = rosterStore
        // 启动先尝试加载已导入的名单（存在 App Support 里，关掉再开还在）
        if let seedRoster {
            activeClasses = seedRoster
            importedRosterName = seedName
        } else if autoloadImported, let (classes, name) = readImportedRoster() {
            activeClasses = classes
            importedRosterName = name
        }
        load()
        diceValues = Array(repeating: 1, count: max(1, min(diceCount, 8)))
        Sound.enabled = soundOn
        Sound.themeStyle = SoundTheme.resolve(soundStyle)
    }

    // MARK: - 持久化

    private func load() {
        // ⚠️ 加载期间禁止回写。`selection` 的 didSet 会 persist()，
        // 而那一刻 drawnByClass / numDrawn 还没读出来 —— 磁盘上刚存的记录会被
        // 默认空值覆盖（内存里后来补回来了，但磁盘已经是空的，下次崩溃/强退就真丢了）。
        isLoading = true
        defer { isLoading = false }

        // 历史存在独立的 key（JSON Data），必须在下面那个 guard 之前读 ——
        // 否则「只导入过名单、还没改过任何设置」的状态下会直接 return，历史永远是空的。
        loadHistory()

        guard let d = defaults.dictionary(forKey: storageKey) else { return }
        // 记住的班级必须还在当前名单里，否则退回第一个班（没名单就是空串）
        if let v = d["classID"] as? String, activeClasses.contains(where: { $0.id == v }) {
            classID = v
        } else {
            classID = activeClasses.first?.id ?? ""
        }
        if let v = d["selection"] as? String {
            if v.hasPrefix("class-") {
                // 上次待的班可能已经不在名单里（换过名单 / 名单被移除），那就退回当前班
                let id = String(v.dropFirst(6))
                selection = .classroom(activeClasses.contains { $0.id == id } ? id : classID)
            } else if v.hasPrefix("tool-"),
                      let t = Tool(rawValue: String(v.dropFirst(5))) {
                selection = .tool(t)
            } else if v == "settings" {
                selection = .settings
            } else if v == "history" {
                selection = .history
            }
        }
        if let v = d["padZero"] as? Bool { padZero = v }
        if let v = d["noRepeat"] as? Bool { noRepeat = v }
        if let v = d["drawnByClass"] as? [String: [Int]] { drawnByClass = v }
        if let v = d["numMin"] as? Int { numMin = v }
        if let v = d["numMax"] as? Int { numMax = v }
        if let v = d["numCount"] as? Int { numCount = v }
        if let v = d["numUnique"] as? Bool { numUnique = v }
        if let v = d["numNoRepeat"] as? Bool { numNoRepeat = v }
        if let v = d["numDrawn"] as? [Int] { numDrawn = v }
        if let v = d["diceCount"] as? Int { diceCount = v }
        if let v = d["diceFaces"] as? Int { diceFaces = v }
        if let v = d["includeJokers"] as? Bool { includeJokers = v }
        if let v = d["cardDrawCount"] as? Int { cardDrawCount = v }
        if let v = d["paletteMode"] as? String, let m = ColorPaletteMode(rawValue: v) { paletteMode = m }
        if let v = d["letterScope"] as? String, let s = LetterScope(rawValue: v) { letterScope = s }
        if let v = d["letterUppercase"] as? Bool { letterUppercase = v }
        if let v = d["rosterOverrides"] as? [String: [String]] { rosterOverrides = v }
        if let v = d["coinHeads"] as? Int { coinHeads = v }
        if let v = d["coinTails"] as? Int { coinTails = v }
        if let v = d["rpsWins"] as? Int { rpsWins = v }
        if let v = d["rpsLosses"] as? Int { rpsLosses = v }
        if let v = d["rpsDraws"] as? Int { rpsDraws = v }
        if let v = d["yesCount"] as? Int { yesCount = v }
        if let v = d["noCount"] as? Int { noCount = v }
        if let v = d["pickCount"] as? Int { pickCount = v }
        if let v = d["soundOn"] as? Bool { soundOn = v }
        if let v = d["celebrationStyle"] as? String { celebrationStyle = v }
        if let v = d["soundStyle"] as? String { soundStyle = v }
        if let v = d["stageScale"] as? Double { stageScale = min(max(v, 0.8), 1.6) }
        if let v = d["pickSpeed"] as? Double { pickSpeed = min(max(v, 0.5), 1.8) }
        if let v = d["soundVolume"] as? Double { soundVolume = min(max(v, 0), 1) }
        if let v = d["groupMode"] as? String, let m = GroupMode(rawValue: v) { groupMode = m }
        if let v = d["groupCount"] as? Int { groupCount = v }
        if let v = d["groupSize"] as? Int { groupSize = v }
        if let v = d["groupShowNumbers"] as? Bool { groupShowNumbers = v }
        if let v = d["effectLevel"] as? String,
           let level = EffectLevel(rawValue: v) { effectLevel = level }
    }

    func persist() {
        guard !isLoading else { return }
        defaults.set([
            "classID": classID,
            "selection": selection.id,
            "padZero": padZero, "noRepeat": noRepeat, "pickCount": pickCount,
            "soundOn": soundOn,
            "celebrationStyle": celebrationStyle, "soundStyle": soundStyle,
            "effectLevel": effectLevel.rawValue,
            "drawnByClass": drawnByClass,
            "numMin": numMin, "numMax": numMax, "numCount": numCount, "numUnique": numUnique,
            "numNoRepeat": numNoRepeat, "numDrawn": numDrawn,
            "diceCount": diceCount, "diceFaces": diceFaces,
            "includeJokers": includeJokers, "cardDrawCount": cardDrawCount,
            "paletteMode": paletteMode.rawValue,
            "letterScope": letterScope.rawValue, "letterUppercase": letterUppercase,
            "rosterOverrides": rosterOverrides,
            "coinHeads": coinHeads, "coinTails": coinTails,
            "rpsWins": rpsWins, "rpsLosses": rpsLosses, "rpsDraws": rpsDraws,
            "yesCount": yesCount, "noCount": noCount,
            "stageScale": stageScale,
            "pickSpeed": pickSpeed, "soundVolume": soundVolume,
            "groupMode": groupMode.rawValue, "groupCount": groupCount,
            "groupSize": groupSize, "groupShowNumbers": groupShowNumbers,
        ], forKey: storageKey)
    }

    // MARK: 历史的落盘

    @ObservationIgnored private let historyKey = "cn.renqiaoyi.random.history.v1"

    private func loadHistory() {
        guard let data = defaults.data(forKey: historyKey) else { return }
        // 读坏了就当空 —— 历史不是关键数据，绝不能因为它解不开就让 App 起不来。
        guard let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        history = decoded.count > Self.historyLimit
            ? Array(decoded.suffix(Self.historyLimit))
            : decoded
    }

    private func persistHistory() {
        guard !isLoading else { return }
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: historyKey)
    }

    // MARK: - 外部名单导入

    /// 真实用户数据里名单的固定位置（App Support 下）。导入/启动时都读这里。
    private static func defaultRosterURL() -> URL? {
        guard let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return base
            .appendingPathComponent("cn.renqiaoyi.random")
            .appendingPathComponent("Imported/active.randomroster")
    }

    /// 本次实例实际用的名单路径：测试注入优先，否则用真实位置。
    private var rosterFileURL: URL? { rosterStoreOverride ?? AppModel.defaultRosterURL() }

    /// 读回已保存的名单（启动时调用）。没有导入过就返回 nil，界面显示空状态。
    private func readImportedRoster() -> (classes: [ClassRoster.SchoolClass], name: String?)? {
        guard let url = rosterFileURL,
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let fmt = try? RosterFormat.parse(url: url) else { return nil }
        return (fmt.toSchoolClasses(), fmt.name)
    }

    /// 把外部名单解析结果写入磁盘，供下次启动自动加载。
    ///
    /// 覆盖前会把旧文件挪一份成 `previous.randomroster` ——
    /// 名单是老师花时间整理的东西，万一新导入的文件有问题，旁边永远留着上一版。
    private func saveImportedRoster(_ fmt: RosterFormat) throws {
        guard let url = rosterFileURL else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            let prev = url.deletingLastPathComponent().appendingPathComponent("previous.randomroster")
            try? FileManager.default.removeItem(at: prev)
            try? FileManager.default.copyItem(at: url, to: prev)
        }
        let data = try fmt.prettyJSON()
        try data.write(to: url, options: .atomic)
    }

    /// 换上新的班级名单，并把当前选中项校正到名单内。
    ///
    /// 导入、清除、自测造数据都走这里，保证 `classID` / `selection` 永远指向真实存在的班。
    func applyRoster(_ classes: [ClassRoster.SchoolClass], name: String?) {
        activeClasses = classes
        importedRosterName = name
        if !activeClasses.contains(where: { $0.id == classID }) {
            let first = activeClasses.first?.id ?? ""
            classID = first
            if case .classroom = selection { selection = .classroom(first) }
        }
    }

    /// 导入一份名单文件（.randomroster / .json）。返回给 UI 用的结果。
    @discardableResult
    func loadRoster(url: URL) -> (ok: Bool, message: String) {
        let src = url.pathExtension.lowercased()
        guard ["randomroster", "json"].contains(src) else {
            return (false, "只支持 .randomroster 或 .json 名单文件")
        }
        do {
            let fmt = try RosterFormat.parse(url: url)
            let classes = fmt.toSchoolClasses()
            guard !classes.isEmpty else { return (false, "这份名单里没有任何班级") }
            try saveImportedRoster(fmt)
            applyRoster(classes, name: fmt.name)
            // 刚导入就跳到第一个班，省得用户自己找
            if let first = classes.first?.id { selection = .classroom(first) }
            persist()
            let n = classes.reduce(0) { $0 + $1.count }
            let title = fmt.name.map { "「\($0)」" } ?? "外部名单"
            return (true, "已导入\(title)：\(classes.count) 个班、共 \(n) 人")
        } catch {
            return (false, "导入失败：\(error.localizedDescription)")
        }
    }

    /// 移除当前名单，回到「未导入」状态（界面重新显示引导导入的空状态）。
    ///
    /// 只动名单本身，不清点名记录——换一份名单回来时记录还在。
    func clearRoster() {
        if let url = rosterFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        applyRoster(ClassRoster.empty, name: nil)
        rosterOverrides = [:]
        persist()
    }

    /// 侧边栏的选择被系统置空时（手势返回列表 / 取消选中）的兜底：落回当前班级。
    ///
    /// ⚠️ 不能"什么都不做"——那样 `selection` 会和界面对不上，
    /// 之后点任何一项都因为"值没变化"而不推页面，表现就是**点了没反应（像卡死）**。
    func selectionCleared() {
        selection = .classroom(classID)
    }

    /// 把「黑桃A」还原成一张牌（历史记录、文本导入都可能用到）
    static func parseCard(_ s: String) -> PlayingCard? {
        if s == "小王" || s == "大王" { return PlayingCard(rank: s, suit: nil) }
        for suit in PlayingCard.Suit.allCases where s.hasPrefix(suit.label) {
            let rank = String(s.dropFirst(suit.label.count))
            if !rank.isEmpty { return PlayingCard(rank: rank, suit: suit) }
        }
        return nil
    }

    // MARK: - 随机算法

    /// 闭区间均匀整数：系统密码学随机源 + 拒绝采样，消除取模偏斜。
    func randInt(_ lo: Int, _ hi: Int) -> Int {
        guard hi > lo else { return lo }
        let span = UInt64(hi - lo + 1)
        let limit = UInt64.max - (UInt64.max % span)
        var x: UInt64 = 0
        repeat { x = UInt64.random(in: 0...UInt64.max) } while x >= limit
        return lo + Int(x % span)
    }

    func sample<T>(_ pool: [T], _ k: Int) -> [T] {
        var rest = pool
        var out: [T] = []
        for _ in 0..<min(k, rest.count) {
            out.append(rest.remove(at: randInt(0, rest.count - 1)))
        }
        return out
    }

    // MARK: - 随机顺序

    /// 打乱后的学号顺序（发言、排队、分站轮转用）。
    var sequenceResult: [Int] = []
    var sequenceRolling: Bool = false

    /// 纯函数：把 1…n 洗一遍。自测可以直接调它，验「不重复、不遗漏」。
    func shuffledOrder() -> [Int] {
        let n = currentNames.count
        guard n > 1 else { return n == 1 ? [1] : [] }
        return sample(Array(1...n), n)
    }

    /// 打乱全班顺序。
    ///
    /// 和「点名」不是一回事：点名每次只要一个人，这个要的是**全班的一个排列**。
    /// 课堂里的真实用途是排发言顺序、排队、分站轮转 —— 只抽一个人解决不了。
    func drawSequence() {
        guard !sequenceRolling, currentNames.count > 1 else { return }
        let final = shuffledOrder()
        sequenceRolling = true
        finishAfter(0.95, tick: 0.060, tickEnd: 0.038, sound: .shuffle, roll: {
            self.sequenceResult = self.shuffledOrder()
        }, settle: {
            Sound.shared.victory()
            self.sequenceRolling = false
            self.sequenceResult = final
            self.cheer()
            self.logHistory(kind: Tool.sequence.rawValue,
                            text: final.map { self.name(no: $0) ?? "\($0) 号" }
                                .joined(separator: "、"))
        })
    }

    /// 顺序表的纯文本（复制到剪贴板 / 贴进班级群）
    var sequencePlainText: String {
        guard !sequenceResult.isEmpty else { return "" }
        return sequenceResult.enumerated().map { i, no in
            "\(i + 1). \(name(no: no) ?? "\(no) 号")"
        }.joined(separator: "\n")
    }

    // MARK: - 随机数字

    /// 本次该抽哪些号。纯函数，不改状态 —— 抽完了返回空数组。
    ///
    /// ⚠️ 抽成纯函数的另一个原因：自测要能连抽几十次验证「绝不重复」，
    /// 不能每次都等那 2 秒动画。
    func nextNumbers() -> [Int] {
        let pool = numPool
        guard !pool.isEmpty else { return [] }
        let k = min(max(1, numCount), 20)
        let take = min(k, pool.count)
        // 「抽过的不再抽」开启时，同一批也必须互不相同 —— 否则一个号码会在一批里出现两次，
        // 与「抽过的不再抽」自相矛盾。
        if numUnique || numNoRepeat {
            return sample(pool, take)
        }
        return (0..<k).map { _ in randInt(numLo, numHi) }
    }

    /// 落定：写入结果，并把号码记进「抽过」池。
    /// 自测直接调它，省得等动画。
    func commitNumbers(_ final: [Int]) {
        numResults = final
        if numNoRepeat {
            var cur = numDrawn
            for n in final where !cur.contains(n) { cur.append(n) }
            numDrawn = cur
        }
        persist()
    }

    func drawNumbers() {
        guard !numRolling else { return }
        guard numHi >= numLo else { return }
        let k = min(max(1, numCount), 20)

        // 号码池已经把「抽过的」排掉了。池空 = 这一轮全抽完了。
        let final = nextNumbers()
        guard !final.isEmpty else {
            numResults = []
            return
        }

        numRolling = true
        finishAfter(2.0, tick: 0.118, tickEnd: 0.042, sound: .number, roll: {
            self.numResults = (0..<k).map { _ in self.randInt(self.numLo, self.numHi) }
        }, settle: {
            Sound.shared.victory()
            self.numRolling = false
            self.commitNumbers(final)
            self.cheer()
            self.logHistory(kind: Tool.randomNumber.rawValue,
                            text: final.map(String.init).joined(separator: " "))
        })
    }

    // MARK: - 骰子

    func rollDice() {
        guard !diceRolling else { return }
        diceCount = min(max(1, diceCount), 8)
        let faces = max(2, diceFaces)
        let final = (0..<diceCount).map { _ in randInt(1, faces) }

        diceRolling = true
        finishAfter(0.95, tick: 0.062, tickEnd: 0.040, sound: .dice, roll: {
            self.diceValues = (0..<self.diceCount).map { _ in self.randInt(1, faces) }
        }, settle: {
            Sound.shared.settle(.dice)
            self.diceRolling = false
            self.diceValues = final
            let text = final.count > 1
                ? "\(final.map(String.init).joined(separator: " + ")) = \(final.reduce(0, +))"
                : "\(final.first ?? 1)"
            self.logHistory(kind: Tool.dice.rawValue, text: text)
        })
    }

    // MARK: - 硬币

    func flipCoin() {
        guard !coinRolling else { return }
        let heads = randInt(0, 1) == 0

        coinRolling = true

        finishAfter(0.9, tick: 0.075, tickEnd: 0.05, sound: .coin, roll: {
            self.coinIsHeads = self.randInt(0, 1) == 0
        }, settle: {
            Sound.shared.settle(.coin)
            self.coinRolling = false
            self.coinIsHeads = heads
            if heads { self.coinHeads += 1 } else { self.coinTails += 1 }
            self.persist()
            self.logHistory(kind: Tool.coin.rawValue, text: heads ? "正面" : "反面")
        })
    }

    func resetCoin() {
        coinHeads = 0; coinTails = 0
        persist()
    }

    // MARK: - 抽卡

    func drawCards() {
        guard !cardRolling else { return }
        let n = min(max(1, cardDrawCount), 10)
        let deck = PlayingCard.fullDeck(includeJokers: includeJokers)
        let final = sample(deck, n)

        cardRolling = true
        finishAfter(1.05, tick: 0.07, tickEnd: 0.045, sound: .card, roll: {
            self.cards = self.sample(deck, n)
        }, settle: {
            Sound.shared.settle(.card)
            self.cardRolling = false
            self.cards = final
            self.logHistory(kind: Tool.card.rawValue,
                            text: final.map(\.displayName).joined(separator: "、"))
        })
    }

    // MARK: - 随机颜色

    func drawColor() {
        guard !colorRolling else { return }
        let target = randomColorComponents()

        colorRolling = true
        finishAfter(0.8, tick: 0.06, tickEnd: 0.045, sound: .color, roll: {
            let c = self.randomColorComponents()
            self.applyColor(h: c.0, s: c.1, b: c.2)
        }, settle: {
            Sound.shared.settle(.color)
            self.colorRolling = false
            self.applyColor(h: target.0, s: target.1, b: target.2)
            self.logHistory(kind: Tool.color.rawValue, text: self.colorHex)
        })
    }

    private func randomColorComponents() -> (Double, Double, Double) {
        let h = Double(randInt(0, 359))
        switch paletteMode {
        case .full:   return (h, Double(randInt(30, 100)) / 100, Double(randInt(45, 100)) / 100)
        case .bright: return (h, Double(randInt(65, 100)) / 100, Double(randInt(85, 100)) / 100)
        case .pastel: return (h, Double(randInt(18, 48)) / 100, Double(randInt(90, 100)) / 100)
        case .deep:   return (h, Double(randInt(50, 90)) / 100, Double(randInt(35, 60)) / 100)
        }
    }

    /// 把 HSB 落成实际颜色（internal 便于自测）
    func applyColor(h: Double, s: Double, b: Double) {
        colorHue = h; colorSat = s; colorBri = b
        let c = hsbToRGB(h: h, s: s, b: b)
        red = c.0; green = c.1; blue = c.2
        colorHex = String(format: "#%02X%02X%02X",
                          Int((red * 255).rounded()),
                          Int((green * 255).rounded()),
                          Int((blue * 255).rounded()))
    }

    var colorSwatch: Color { Color(.sRGB, red: red, green: green, blue: blue) }

    var colorRGBText: String {
        "R \(Int((red * 255).rounded()))　G \(Int((green * 255).rounded()))　B \(Int((blue * 255).rounded()))"
    }

    var colorHSBText: String {
        "H \(Int(colorHue.rounded()))°　S \(Int((colorSat * 100).rounded()))%　B \(Int((colorBri * 100).rounded()))%"
    }

    func copyHex() {
        Pasteboard.copy(colorHex)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.copied = false }
    }

    // MARK: - 随机字母

    func drawLetter() {
        guard !letterRolling else { return }
        let pool = letterScope.letters
        let final = pool[randInt(0, pool.count - 1)]

        letterRolling = true
        finishAfter(2.0, tick: 0.118, tickEnd: 0.042, sound: .letter, roll: {
            let p = self.letterScope.letters
            self.letterResult = p[self.randInt(0, p.count - 1)]
        }, settle: {
            Sound.shared.victory()
            self.letterRolling = false
            self.letterResult = final
            self.cheer()
            self.logHistory(kind: Tool.letter.rawValue, text: self.letterDisplay(final))
        })
    }

    func letterDisplay(_ s: String) -> String { letterUppercase ? s : s.lowercased() }

    // MARK: - 剪刀石头布

    func play(_ move: RPS) {
        guard !rpsRolling else { return }
        let ai = RPS.allCases[randInt(0, 2)]

        myMove = move
        rpsRolling = true
        aiMove = RPS.allCases[randInt(0, 2)]

        finishAfter(0.85, tick: 0.085, tickEnd: 0.06, sound: .rps, roll: {
            self.aiMove = RPS.allCases[self.randInt(0, 2)]
        }, settle: {
            Sound.shared.settle(.rps)
            self.rpsRolling = false
            self.aiMove = ai
            let outcome: String
            switch move.versus(ai) {
            case 1:  self.rpsWins += 1;   outcome = "你赢了"
            case -1: self.rpsLosses += 1; outcome = "你输了"
            default: self.rpsDraws += 1;  outcome = "平局"
            }
            self.persist()
            self.logHistory(kind: Tool.rockPaperScissors.rawValue,
                            text: "\(move.title) vs \(ai.title) · \(outcome)")
        })
    }

    var rpsResultText: String {
        guard let my = myMove, let ai = aiMove, !rpsRolling else { return "选一个出拳" }
        switch my.versus(ai) {
        case 1:  return "你赢了"
        case -1: return "你输了"
        default: return "平局"
        }
    }

    func resetRPS() {
        myMove = nil; aiMove = nil
        rpsWins = 0; rpsLosses = 0; rpsDraws = 0
        persist()
    }

    // MARK: - 是或否

    func drawYesNo() {
        guard !yesNoRolling else { return }
        let final = randInt(0, 1) == 0

        yesNoRolling = true
        finishAfter(2.0, tick: 0.118, tickEnd: 0.042, sound: .yesNo, roll: {
            self.yesNoResult = self.randInt(0, 1) == 0
        }, settle: {
            Sound.shared.victory()
            self.yesNoRolling = false
            self.yesNoResult = final
            if final { self.yesCount += 1 } else { self.noCount += 1 }
            self.cheer()
            self.persist()
            self.logHistory(kind: Tool.yesNo.rawValue, text: final ? "是" : "否")
        })
    }

    func resetYesNo() {
        yesNoResult = nil
        yesCount = 0
        noCount = 0
        persist()
    }

    // MARK: - 统一入口

    func step(_ delta: Int) {
        let all = allSidebarItems
        guard let i = all.firstIndex(of: selection) else { return }
        let n = all.count
        selection = all[((i + delta) % n + n) % n]
    }

    var allSidebarItems: [SidebarItem] {
        activeClasses.map { SidebarItem.classroom($0.id) }
            + Tool.allCases.map { SidebarItem.tool($0) }
            + [.history]
    }

    func performPrimaryAction() {
        switch selection {
        case .classroom:          drawPick()
        case .tool(.grouping):          drawGroups()
        case .tool(.sequence):          drawSequence()
        case .tool(.randomNumber):      drawNumbers()
        case .tool(.dice):              rollDice()
        case .tool(.coin):              flipCoin()
        case .tool(.card):              drawCards()
        case .tool(.color):             drawColor()
        case .tool(.letter):            drawLetter()
        case .tool(.rockPaperScissors): break
        case .tool(.yesNo):             drawYesNo()
        case .history:                  break
        case .settings:                 break
        }
    }

    func undoCurrent() {
        if case .classroom = selection { undoPick() }
    }

    func resetCurrent() {
        switch selection {
        case .classroom:                resetPick()
        case .tool(.grouping):          resetGroups()
        case .tool(.sequence):          sequenceResult = []
        case .tool(.randomNumber):      resetNumbers()
        case .tool(.dice):              diceValues = Array(repeating: 1, count: diceCount)
        case .tool(.coin):              resetCoin()
        case .tool(.card):              cards = []
        case .tool(.color):             break
        case .tool(.letter):            letterResult = ""
        case .tool(.rockPaperScissors): resetRPS()
        case .tool(.yesNo):             resetYesNo()
        case .history:                  break
        case .settings:                 break
        }
    }

    /// 是否有可清空的记录（决定工具栏按钮是否可用）
    var hasRecords: Bool {
        switch selection {
        case .classroom:                return !drawn.isEmpty
        case .tool(.grouping):          return !groups.isEmpty
        case .tool(.sequence):          return !sequenceResult.isEmpty
        case .tool(.randomNumber):      return !numResults.isEmpty || !numDrawn.isEmpty
        case .tool(.dice):              return diceValues.contains { $0 != 1 }
        case .tool(.coin):              return coinHeads + coinTails > 0
        case .tool(.card):              return !cards.isEmpty
        case .tool(.color):             return false
        case .tool(.letter):            return !letterResult.isEmpty
        case .tool(.rockPaperScissors): return rpsWins + rpsLosses + rpsDraws > 0
        case .tool(.yesNo):             return yesCount + noCount > 0
        case .history:                  return false     // 历史页有自己的「清空」，带二次确认
        case .settings:                 return false
        }
    }

    var isRolling: Bool {
        switch selection {
        case .classroom:                return pickRolling
        case .tool(.grouping):          return groupingRolling
        case .tool(.sequence):          return sequenceRolling
        case .tool(.randomNumber):      return numRolling
        case .tool(.dice):              return diceRolling
        case .tool(.coin):              return coinRolling
        case .tool(.card):              return cardRolling
        case .tool(.color):             return colorRolling
        case .tool(.letter):            return letterRolling
        case .tool(.rockPaperScissors): return rpsRolling
        case .tool(.yesNo):             return yesNoRolling
        case .history:                  return false
        case .settings:                 return false
        }
    }

    var actionTitle: String {
        switch selection {
        case .classroom:   return "点名"
        case .tool(let t): return t.actionTitle
        case .history:     return "历史记录"
        case .settings:    return "设置"
        }
    }

    // MARK: - 计时器

    /// 抽取过程的驱动：`tick` → `tickEnd` 之间线性加速，越到后面鼓点越密。
    /// 每一拍同时推进一次随机滚动并播一记鼓点，做出「哒哒哒」往上顶的紧张感。
    ///
    /// `sound` 指定这一轮用哪个工具的过程音 —— 骰子滚桌、硬币叮当、
    /// 抽卡洗牌、点名木牌……原来十一个工具共用一套嘟嘟嘟，听不出在干什么。
    private func finishAfter(_ duration: Double,
                             tick tickStart: Double,
                             tickEnd: Double? = nil,
                             sound tool: ToolSound,
                             roll: @escaping () -> Void,
                             settle: @escaping () -> Void) {
        timer?.invalidate()
        Sound.shared.beginRound(tool)   // 每轮换一套鼓点音色 + 重新允许上扬音
        // 节奏倍率在这里一次乘完：所有工具传的都是「标准时长」，
        // 设置里调到 0.6 倍就全都变快，不用回头改 8 个 draw 函数。
        let duration = duration * effectivePickSpeed
        let begin = Date()
        let deadline = begin.addingTimeInterval(duration)
        let end = tickEnd ?? tickStart
        var lastTick = Date.distantPast
        // roll / settle 自身已持有模型引用，这里不再弱捕获，省掉多余的 guard。
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { t in
            let now = Date()
            if now >= deadline {
                t.invalidate()
                settle()
                return
            }
            let p = min(1, max(0, now.timeIntervalSince(begin) / duration))
            let interval = tickStart + (end - tickStart) * p
            if now.timeIntervalSince(lastTick) >= interval {
                lastTick = now
                roll()
                Sound.shared.tick(p, tool)
            }
        }
    }

    deinit { timer?.invalidate() }
}
