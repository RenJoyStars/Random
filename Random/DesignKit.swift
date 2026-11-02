import SwiftUI

// MARK: - 字号阶梯
//
// 3.0 里字号是随手写的：8.5 / 10.5 / 11.5 / 12.5 这些半点值散在各处，
// 相邻两行文字会差半号，读者说不上来哪里怪，但就是"不齐"。
// 3.1 起全工程只用下面这几档，`run-tests.sh` 会扫描源码里的字面量把关。
//
//   9   符号级（箭头、角标）
//   10  徽标数字、磁贴图标
//   11  提示、辅助说明、单位
//   12  次级标签（数值后缀、表头、搜索框）
//   13  正文：侧边栏行 / 设置项标题 / 记录胶囊 —— 全工程出现最多的一档
//   14  小标题（分组名）
//   15  卡片标题
//   16  面板标题
//   17  磁贴数值、区块标题
//   20  主按钮标题
//   22  舞台小字 / 次级结果
//   25 以上为舞台区动态尺寸，见各视图里的 stageScale 计算
enum Type {
    static let micro: CGFloat = 9
    static let tiny: CGFloat = 10
    static let caption: CGFloat = 11
    static let footnote: CGFloat = 12
    static let body: CGFloat = 13
    static let label: CGFloat = 14
    static let cardTitle: CGFloat = 15
    static let panelTitle: CGFloat = 16
    static let title: CGFloat = 17
    static let button: CGFloat = 20
}

// MARK: - 绑定助手

extension AppModel {
    func binding<V>(_ keyPath: ReferenceWritableKeyPath<AppModel, V>) -> Binding<V> {
        Binding(get: { self[keyPath: keyPath] },
                set: { self[keyPath: keyPath] = $0 })
    }
}

// MARK: - 带下标的可哈希包装

struct Indexed<Value: Hashable>: Hashable, Identifiable {
    let index: Int
    let value: Value
    var id: Int { index }
}

// MARK: - 结果舞台

struct StageCard<Content: View>: View {
    var minHeight: CGFloat = 200
    let content: Content

    init(minHeight: CGFloat = 200, @ViewBuilder content: () -> Content) {
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            // 内容区**不做** Liquid Glass。
            //
            // HIG 明确写了两条：液态玻璃只用于导航层（边栏、工具栏、浮层），
            // 铺到内容层会把层级糊掉；而且"为强调而加的装饰背景要删掉"。
            // 这里改用系统的 controlBackground 做一块实心卡片，
            // 边界靠一道 0.5pt 的 separator —— macOS 的层次是"三档灰 + 细线"，
            // 不是阴影和发光。深浅色切换时这块颜色由系统负责。
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.semantic(.controlBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.semantic(.separator), lineWidth: 0.5)
            }
    }
}

// MARK: - 结果文字

struct BigNumber: View {
    let text: String
    var size: CGFloat = 132
    var weight: Font.Weight = .bold

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.22)
            .contentTransition(.numericText())
            .foregroundStyle(.primary)
    }
}

struct BigNumberWithUnit: View {
    let text: String
    var size: CGFloat = 132

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(text)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.22)
                .contentTransition(.numericText())
            Text("号")
                .font(.system(size: size * 0.3, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

struct StageBadge<Value: Equatable>: View {
    let symbol: String
    var value: Value
    var tint: Color = .accentColor
    /// 给 VoiceOver 念的话。不给就当装饰隐藏 ——
    /// 否则它会念出「graduation cap」这种符号名，对盲人用户毫无意义
    /// （这个图标的真正含义是「刚刚出了新结果」）。
    var a11yLabel: String? = nil

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(tint)
            .symbolEffect(.bounce, value: value)
            .accessibilityLabel(a11yLabel ?? "")
            .accessibilityHidden(a11yLabel == nil)
    }
}

struct StageCaption: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

// MARK: - 空状态

struct EmptyStage: View {
    var text: String = "待抽取"
    var symbol: String = "sparkles"
    var height: CGFloat = 110

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)      // 纯装饰，下面的文字已经说明一切
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 280)
        .frame(height: height)
        // 空状态是"坑位"不是"按钮"：填一层几乎看不见的底色 + 虚线。
        // 之前只有虚线、还是 .quaternary，投影仪上基本消失，
        // 学生看见的就是一大片空白。
        //
        // 圆角 10 而不是 18：它长在圆角 12 的卡片里，
        // 内层圆角必须比外层小一圈（同心圆角），否则内框看着比外框还圆。
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.4, dash: [7, 7]))
                        .foregroundStyle(.secondary.opacity(0.30))
                }
        }
    }
}

// MARK: - 主操作按钮

struct PrimaryButton: View {
    let title: String
    var symbol: String = "sparkles"
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            // 宽度锁在内容尺寸：macOS 没有「通栏主按钮」这种东西。
            //
            // 之前是 `.frame(maxWidth: .infinity)` 铺满内容区（约 1000pt），
            // 一整条满饱和蓝横贯窗口 —— 那是 iOS 的 confirm 按钮语言，
            // 在 Mac 上会压过页面内容，而且和系统里任何一个按钮都对不上。
            // 现在 176pt 起跳（够「换一个颜色」五个字），随文字自然伸缩，
            // 靠 VStack 的居中排布落在卡片下方正中间。
            .frame(minWidth: 176)
            .padding(.horizontal, 18)
            .padding(.vertical, 2)
        }
        // 主操作就用系统的 prominent 按钮。
        //
        // 之前自绘了一版蓝紫渐变 + 光晕投影，看着"设计感"更强，但那恰恰是
        // 反原生的：macOS 的主按钮只由系统着色（跟随用户的强调色设置），
        // 不自己调色。用户把强调色改成石墨/橙色时，自绘的那版就和人家的
        // 系统控件对不上了；系统按钮会自动跟着走。
        //
        // 尺寸用 .large（≈28pt）而不是 .extraLarge：后者是 36pt 的大块头，
        // 在 Mac 上只有「首次启动配置」那种引导页才用。
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(disabled)
        .keyboardShortcut(.defaultAction)
    }
}

// MARK: - 数据磁贴
// 比裸数字好看：浅底圆角 + 大号数值 + 小标签。

struct StatTile: View {
    let value: String
    let label: String
    var tint: Color = .primary
    var symbol: String?

    var body: some View {
        // 不再画彩色底块。
        //
        // 之前是「灰底 / 蓝底」两个圆角小方块并排 —— 那是 iOS 小组件的语言，
        // 放在 Mac 的分组卡片里会有两个问题：一是蓝底和主按钮的蓝撞在一起，
        // 二是两个并排的色块看上去像两个可点的按钮，其实都不可点。
        // 现在就是「大数字 + 小标签」，颜色只用来表示异常（剩余 0 变红）。
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 19, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            HStack(spacing: 3) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 62, alignment: .leading)
        .animation(.snappy(duration: 0.18), value: value)
    }
}

// MARK: - 区块小标题
// 直接放在页面上的分组标题（不再套面板），可带数量与右侧操作。

struct SectionLabel<Trailing: View>: View {
    let title: String
    var count: String?
    let trailing: Trailing

    init(_ title: String, count: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.count = count
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            if let count {
                Text(count)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 4)
        // 10 而不是 6：工具页的 VStack 间距统一是 16，区块标题若只多 6，
        // 「主按钮 → 标题」和「标题 → 卡片」几乎等距，读起来就是一堆平均分布的块。
        // 加到这里，主按钮自成一段、下面的设置从标题重新开始。
        .padding(.top, 10)
        .frame(minHeight: 26)
    }
}

extension SectionLabel where Trailing == EmptyView {
    init(_ title: String, count: String? = nil) {
        self.init(title, count: count) { EmptyView() }
    }
}

// MARK: - 卡片组
//
// macOS 的设置型界面是「一个组 = 一张圆角卡片，组内多行之间一条细线」，
// 不是「每行一张卡片」。之前每行独立成卡片、行间留 16pt，
// 读起来像一堆并列的积木，看不出哪几行属于同一件事。
//
// 分隔线的做法：VStack 的间距设成 0.5pt，外层铺一层 separator 色，
// 行自己的背景是实心 controlBackground —— 透出来的那 0.5pt 就是线。
// 这样不用知道谁是第一行、谁是最后一行。

private struct InCardGroupKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var inCardGroup: Bool {
        get { self[InCardGroupKey.self] }
        set { self[InCardGroupKey.self] = newValue }
    }
}

struct CardGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0.5) {
            content
        }
        .background(Color.semantic(.separator))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.semantic(.separator), lineWidth: 0.5)
        }
        .environment(\.inCardGroup, true)
    }
}

// MARK: - 横条
// 每个选项占一条。和舞台卡片用同一套材料（controlBackground + 0.5pt 细线），
// 只是圆角小一号 —— 原生 app 里"同一个层级的容器长同一个样"。

struct Bar<Content: View>: View {
    @Environment(\.inCardGroup) private var grouped

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 14)
            // 组内行挨着排，上下留白要收一点；独立成卡时给足呼吸。
            .padding(.vertical, grouped ? 9 : 11)
            .frame(maxWidth: .infinity, minHeight: grouped ? nil : 44, alignment: .leading)
            .background {
                // 组内只铺实心底色，圆角和描边由 CardGroup 统一负责；
                // 独立成卡时自己画完整的一张。
                if grouped {
                    Color.semantic(.controlBackground)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.semantic(.controlBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.semantic(.separator), lineWidth: 0.5)
                        }
                }
            }
    }
}

/// 标题在左、控件在右（开关、步进器）
struct OptionBar<Content: View>: View {
    let title: String
    var hint: String?
    let content: Content

    init(_ title: String, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.hint = hint
        self.content = content()
    }

    var body: some View {
        Bar {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13))
                    if let hint {
                        Text(hint).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 14)
                content
            }
        }
    }
}

/// 标题在上、控件在下占满整条（分段选择器）
struct OptionField<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        Bar {
            VStack(alignment: .leading, spacing: 9) {
                Text(title).font(.system(size: 13)).foregroundStyle(.primary)
                content
            }
        }
    }
}

// MARK: - 清空 / 重置按钮

struct ClearButton: View {
    var title: String = "清空"
    var symbol: String = "arrow.counterclockwise"
    var tint: Color = .secondary
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 2)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .tint(tint)
        .disabled(disabled)
    }
}

// MARK: - 记录胶囊
// 比 bordered 按钮更柔和，悬停时高亮，暗示"可点掉"。

struct RecordChip: View {
    let text: String
    var sub: String?
    var wide: Bool = false
    let action: () -> Void

    @State private var hovering = false

    // 不再常驻一块灰底。
    //
    // 之前是一墙灰色胶囊（30 个"01 陈南瑾"），整块区域看着像一堆按钮，
    // 其实只有"点一下放回"一个动作。而且四字姓名在窄胶囊里还会折行，
    // 那一行被撑高，上下就对不齐。
    //
    // 现在是**文字网格**：学号用次级色、姓名用主色，平时没有任何背景，
    // 鼠标移上去才亮一小块。密度高、安静，和左侧栏的名单是同一套语气。
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(text)
                    .monospacedDigit()
                    .foregroundStyle(hovering ? Color.accentColor : Color.secondary)
                if let sub {
                    Text(sub)
                        .foregroundStyle(hovering ? Color.accentColor : Color.primary)
                }
            }
            .font(.system(size: 13))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovering ? Color.accentColor.opacity(0.13) : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("点一下放回")
    }
}


// MARK: - 记录为空时的提示

struct EmptyRecords: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 13))
                .foregroundStyle(.quaternary)
                .accessibilityHidden(true)      // 纯装饰
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}


// MARK: - 输入

struct CountField: View {
    let label: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13).monospacedDigit())
                .frame(width: 84)
                // 上面那个 Text 是独立元素，不会成为输入框的无障碍名称 ——
                // 不显式给的话，VoiceOver 念到输入框只会说「文本框」，用户不知道在改哪一项。
                .accessibilityLabel(label)
        }
    }
}

// MARK: - 数字输入框
// 直接键入数字，不再靠加减按钮。回车或失焦时提交，并夹到合法范围内。

struct NumberField: View {
    var label: String?
    @Binding var value: Int
    var suffix: String?
    var range: ClosedRange<Int>
    var width: CGFloat = 54

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                // 系统输入框。原生 app 里输入框就是 roundedBorder，
                // 自己画一个"更配卡片"的反而会丢掉系统行为（焦点环、右键菜单、输入法样式）。
                TextField("", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13).monospacedDigit())
                    .multilineTextAlignment(.center)
                    .frame(width: width)
                    .focused($focused)
                    .onSubmit(commit)
                    .accessibilityLabel(label ?? "数值")
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { text = String(value) }
        .onChange(of: value) { _, new in
            if !focused { text = String(new) }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
        // 离开页面时也要提交：否则输入到一半直接切页/关面板，输入就被丢掉了
        .onDisappear { commit() }
    }

    private func commit() {
        let typed = Int(text.trimmingCharacters(in: .whitespaces))
        let clamped = min(max(typed ?? value, range.lowerBound), range.upperBound)
        value = clamped
        text = String(clamped)
    }
}

// MARK: - 落定特效（4 种主题 · 每次随机）
//
// 点名或抽取落定时放一次。纯 Canvas 绘制，不引入任何图片资源。
//
// 为什么要分主题：一套彩带看一学期，学生第三节课就麻了。现在落定时从
// **彩带礼炮 / 连环烟花 / 星芒绽放 / 冲击光环** 里挑一种，每次不一样。
// 主题由 AppModel 决定（设置页可固定成某一种），视图只负责画。

// 主题枚举定义在 AppModel.swift（纯数据、不依赖 SwiftUI，便于无头自测）。

struct CelebrationParticle {
    enum Kind {
        case ribbon   // 纸片（长方，翻转）
        case dot      // 圆点
        case spark    // 带拖尾的星火
        case streak   // 细长光条（星芒）
        case petal    // 花瓣（椭圆，慢转）
        case snow     // 雪花（六角）
        case heart    // 心形
        case star     // 五角星
        case coin     // 金币（扁圆 + 高光）
        case square   // 方块（像素感）
        case bubble   // 气泡（圆环，空心）
        case glow     // 大而淡的光晕（彗星核、新星）
    }

    var x: Double, y: Double          // 起点（归一化到画布宽高）
    var vx: Double, vy: Double        // 速度（每秒多少个画布宽 / 高）
    var spin: Double                  // 每秒转多少度
    var color: Int
    var w: Double, h: Double
    var delay: Double
    var life: Double
    var kind: Kind
    /// 是否受重力（烟花/星芒要轻一些，纸片得往下掉）
    var gravity: Double = 1.0
    /// 横向摆动幅度（画布宽的倍数）。雪花 / 花瓣 / 气泡靠它"飘"起来。
    ///
    /// 纯弹道算出来的下落永远是直线，像石头。真实的花瓣和雪是左右摆着走的，
    /// 所以这里叠一条正弦横移 —— 只是绘制时的偏移，不动速度模型。
    var sway: Double = 0
    /// 摆动频率（每秒几个来回）
    var swayRate: Double = 0
}

struct ConfettiBurst: View {
    var trigger: Int
    var theme: CelebrationTheme = .confetti
    /// 粒子密度：完整 / 精简 / 关闭（见 EffectLevel）
    var level: EffectLevel = .full

    @State private var particles: [CelebrationParticle] = []
    @State private var start: Date = .distantPast
    @State private var alive = false
    /// 收尾用的延时任务。用户抽完立刻切页时视图会被销毁，
    /// 不取消的话任务还会跑满两秒再去写已丢弃视图的状态。
    @State private var settleTask: Task<Void, Never>?

    private var duration: Double { theme.duration }

    private static let palette: [Color] = [
        Color(red: 1.00, green: 0.27, blue: 0.34),   // 红
        Color(red: 1.00, green: 0.62, blue: 0.16),   // 橙
        Color(red: 1.00, green: 0.85, blue: 0.24),   // 金
        Color(red: 0.24, green: 0.78, blue: 0.44),   // 绿
        Color(red: 0.22, green: 0.60, blue: 1.00),   // 蓝
        Color(red: 0.68, green: 0.40, blue: 0.98),   // 紫
        Color(red: 1.00, green: 0.42, blue: 0.72),   // 粉
        Color(red: 0.30, green: 0.86, blue: 0.86),   // 青
    ]

    var body: some View {
        ZStack {
            if alive, level != .off {
                TimelineView(.animation) { timeline in
                    Canvas { ctx, size in
                        let t = timeline.date.timeIntervalSince(start)
                        guard t >= 0, t <= duration else { return }
                        Self.draw(theme, particles: particles, into: &ctx, size: size, t: t)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in burst() }
        .onDisappear { settleTask?.cancel() }
    }

    private func burst() {
        start = Date()
        let all = Self.makeParticles(theme)
        // 精简档直接按比例抽样，不再另写一套参数 —— 观感一致，只是少一半。
        let keep = max(1, Int((Double(all.count) * level.density).rounded()))
        particles = level.density >= 1 ? all : Array(all.shuffled().prefix(keep))
        alive = true
        settleTask?.cancel()
        settleTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            if Date().timeIntervalSince(start) >= duration {
                alive = false
                particles = []
            }
        }
    }

    // MARK: 粒子与绘制（纯函数，可离屏取任意时刻的帧）

    /// 参数化爆发配置。24 种特效里大部分只是这张表的不同填法，
    /// 不再每种手写一个 for 循环 —— 想加第 25 种，加一行配置就够。
    struct BurstSpec {
        struct Source {
            var x: Double
            var y: Double
            var delay: Double = 0
        }

        var sources: [Source] = [Source(x: 0.5, y: 0.46)]
        var count: Int = 40                      // 每个源的粒子数
        var speed: ClosedRange<Double> = 0.3...0.9
        var angle: ClosedRange<Double> = 0...(2 * .pi)   // 弧度
        var spread: Double = 0.03                // 起点抖动
        var gravity: Double = 0.6
        var spin: ClosedRange<Double> = (-400)...400
        var w: ClosedRange<Double> = 0.006...0.014
        var h: ClosedRange<Double> = 0.006...0.014
        var life: ClosedRange<Double> = 1.0...1.8
        var delayJitter: Double = 0.05
        var kind: CelebrationParticle.Kind = .dot
        var colors: [Int] = []                   // 空 = 每个粒子随机
        var sway: Double = 0
        var swayRate: Double = 0
        var radius: Double = 0                   // 起点离源心的半径
        var angularStep: Double = 0              // 每个粒子的角度增量（螺旋）
        var tangential: Double = 0               // 切向速度占比（漩涡）
    }

    static func makeParticles(_ theme: CelebrationTheme) -> [CelebrationParticle] {
        switch theme {

        // ── 经典 ──────────────────────────────────────
        case .confetti:  return confettiParticles()
        case .fireworks: return fireworkParticles()
        case .starburst: return starburstParticles()
        case .rings:     return ringParticles()

        // ── 飘落：从画面上方往下，速度慢、带横向摆动 ──
        case .paperRain:
            return spawn(BurstSpec(
                sources: topRow(14), count: 6,
                speed: 0.0...0.03, angle: 1.25...1.90, spread: 0.035,
                gravity: 0.30, spin: (-660.0)...660.0,
                w: 0.009...0.019, h: 0.013...0.030,
                life: 2.3...2.9, delayJitter: 0.05,
                kind: .ribbon, colors: [0, 1, 2, 3, 4, 5, 6, 7],
                sway: 0.014, swayRate: 0.7))

        case .snow:
            return spawn(BurstSpec(
                sources: topRow(14), count: 6,
                speed: 0.0...0.02, angle: 1.35...1.80, spread: 0.05,
                gravity: 0.14, spin: (-120.0)...120.0,
                w: 0.010...0.017, h: 0.010...0.017,
                life: 2.9...3.2, delayJitter: 0.14,
                kind: .snow, colors: [7, 4, 3],
                sway: 0.030, swayRate: 0.55))

        case .petals:
            return spawn(BurstSpec(
                sources: topRow(12), count: 6,
                speed: 0.0...0.02, angle: 1.30...1.85, spread: 0.045,
                gravity: 0.18, spin: (-520.0)...520.0,
                w: 0.015...0.025, h: 0.021...0.036,
                life: 2.7...3.0, delayJitter: 0.10,
                kind: .petal, colors: [6, 0, 2, 5],
                sway: 0.034, swayRate: 0.85))

        case .leaves:
            return spawn(BurstSpec(
                sources: topRow(12), count: 5,
                speed: 0.0...0.03, angle: 1.20...1.95, spread: 0.05,
                gravity: 0.22, spin: (-780.0)...780.0,
                w: 0.011...0.019, h: 0.016...0.028,
                life: 2.7...3.0, delayJitter: 0.09,
                kind: .petal, colors: [1, 2, 3, 0],
                sway: 0.042, swayRate: 0.95))

        case .goldRain:
            return spawn(BurstSpec(
                sources: topRow(18), count: 4,
                speed: 0.02...0.05, angle: 1.45...1.72, spread: 0.03,
                gravity: 0.55, spin: 0...0,
                w: 0.0022...0.004, h: 0.055...0.115,
                life: 2.0...2.4, delayJitter: 0.08,
                kind: .streak, colors: [2, 1],
                sway: 0.008, swayRate: 0.5))

        case .butterflies:
            return spawn(BurstSpec(
                sources: bottomRow(14), count: 4,
                speed: 0.08...0.20, angle: 4.4...5.0, spread: 0.10,
                gravity: -0.06, spin: (-260.0)...260.0,
                w: 0.019...0.030, h: 0.014...0.022,
                life: 2.5...3.0, delayJitter: 0.35,
                kind: .petal, colors: [6, 4, 2, 7],
                sway: 0.070, swayRate: 1.15))

        // ── 涌动：从下往上，或绕中心转 ──
        case .hearts:
            return spawn(BurstSpec(
                sources: bottomRow(10), count: 4,
                speed: 0.22...0.46, angle: 4.35...5.05, spread: 0.06,
                gravity: 0, spin: (-90.0)...90.0,
                w: 0.012...0.020, h: 0.012...0.020,
                life: 2.2...2.6, delayJitter: 0.25,
                kind: .heart, colors: [0, 6, 2],
                sway: 0.045, swayRate: 0.75))

        case .bubbles:
            return spawn(BurstSpec(
                sources: bottomRow(12), count: 4,
                speed: 0.16...0.38, angle: 4.4...5.0, spread: 0.08,
                gravity: 0.02, spin: 0...0,
                w: 0.008...0.022, h: 0.008...0.022,
                life: 2.4...2.8, delayJitter: 0.30,
                kind: .bubble, colors: [4, 7, 3],
                sway: 0.050, swayRate: 0.9))

        case .fountain:
            return spawn(BurstSpec(
                sources: [BurstSpec.Source(x: 0.5, y: 0.98)],
                count: 64,
                speed: 0.95...1.45, angle: 4.20...5.22, spread: 0.01,
                gravity: 1.55, spin: 0...0,
                w: 0.0035...0.007, h: 0.0035...0.007,
                life: 1.5...1.9, delayJitter: 0.06,
                kind: .dot, colors: [4, 7, 3, 2]))

        case .spiral:
            // 螺旋必须**依次**发射：同一时刻朝各个方向射出去，画出来永远是"环"。
            // 这里让每个粒子比前一个晚 11ms 出发、角度多转 0.28 弧度，
            // 连起来就是一条甩出去的旋臂。
            var arm: [CelebrationParticle] = []
            for i in 0..<72 {
                let a = Double(i) * 0.28
                let speed = 0.50 + 0.32 * (Double(i) / 72)
                arm.append(CelebrationParticle(
                    x: 0.5 + cos(a) * 0.008, y: 0.46 + sin(a) * 0.008,
                    vx: cos(a) * speed, vy: sin(a) * speed,
                    spin: 0,
                    color: [4, 5, 7, 2][i % 4],
                    w: 0.0045 + 0.002 * Double(i % 3),
                    h: 0.0045 + 0.002 * Double(i % 3),
                    delay: Double(i) * 0.011,
                    life: 1.25, kind: .spark, gravity: 0.22))
            }
            return arm

        case .vortex:
            return spawn(BurstSpec(
                sources: [BurstSpec.Source(x: 0.5, y: 0.46)],
                count: 72,
                speed: 0.30...0.62, angle: 0...(2 * .pi), spread: 0,
                gravity: 0.12, spin: 0...0,
                w: 0.004...0.009, h: 0.004...0.009,
                life: 1.4...1.9, delayJitter: 0,
                kind: .spark, colors: [5, 4, 7],
                radius: 0.06, angularStep: 0.12, tangential: 1.15))

        // ── 光效 ──
        case .starfall:
            return spawn(BurstSpec(
                sources: topRow(14), count: 3,
                speed: 0.55...0.95, angle: 0.62...0.95, spread: 0.04,
                gravity: 0.30, spin: 0...0,
                w: 0.0022...0.0042, h: 0.070...0.140,
                life: 1.5...1.9, delayJitter: 0.35,
                kind: .streak, colors: [2, 7, 4]))

        case .neonStreaks:
            return spawn(BurstSpec(
                sources: (0..<8).map { BurstSpec.Source(x: -0.10, y: Double($0) / 8 + 0.04, delay: Double($0) * 0.05) },
                count: 4,
                speed: 1.1...1.9, angle: (-0.10)...(0.10), spread: 0.05,
                gravity: 0, spin: 0...0,
                w: 0.0025...0.0050, h: 0.12...0.26,
                life: 0.9...1.3, delayJitter: 0.06,
                kind: .streak, colors: [7, 4, 5, 6]))

        case .glitter:
            return spawn(BurstSpec(
                sources: (0..<44).map { _ in
                    BurstSpec.Source(x: Double.random(in: 0.04...0.96),
                                     y: Double.random(in: 0.08...0.88),
                                     delay: Double.random(in: 0...0.5))
                },
                count: 4,
                speed: 0.02...0.10, angle: 0...(2 * .pi), spread: 0.02,
                gravity: 0.10, spin: (-200.0)...200.0,
                w: 0.0038...0.0080, h: 0.0038...0.0080,
                life: 0.9...1.6, delayJitter: 0.2,
                kind: .star, colors: [2, 6, 7, 4]))

        case .coins:
            return spawn(BurstSpec(
                sources: topRow(12), count: 4,
                speed: 0.0...0.05, angle: 1.30...1.85, spread: 0.05,
                gravity: 0.68, spin: (-380.0)...380.0,
                w: 0.011...0.019, h: 0.011...0.019,
                life: 2.0...2.5, delayJitter: 0.10,
                kind: .coin, colors: [2, 1],
                sway: 0.010, swayRate: 0.5))

        case .comet:
            // 一个亮核 + 一整条拖尾，从左下往右上斜穿
            var out: [CelebrationParticle] = [
                CelebrationParticle(
                    x: -0.12, y: 0.92, vx: 1.05, vy: -0.52,
                    spin: 0, color: 2, w: 0.050, h: 0.050,
                    delay: 0, life: 1.6, kind: .glow, gravity: 0)
            ]
            for i in 0..<44 {
                let k = Double(i) / 44
                out.append(CelebrationParticle(
                    x: -0.12 - k * 0.30, y: 0.92 + k * 0.15,
                    vx: 1.05, vy: -0.52,
                    spin: 0,
                    color: i % 4 == 0 ? 2 : (i % 3 == 0 ? 1 : 7),
                    w: 0.0050 + 0.006 * (1 - k), h: 0.0050 + 0.006 * (1 - k),
                    delay: k * 0.10, life: 0.7 + 0.5 * (1 - k),
                    kind: .spark, gravity: 0))
            }
            return out

        // ── 爆发 ──
        case .nova:
            var out = spawn(BurstSpec(
                sources: [BurstSpec.Source(x: 0.5, y: 0.46)],
                count: 46,
                speed: 0.22...0.62, angle: 0...(2 * .pi), spread: 0.02,
                gravity: 0.18, spin: (-200.0)...200.0,
                w: 0.005...0.010, h: 0.005...0.010,
                life: 1.2...1.7, delayJitter: 0.04,
                kind: .dot, colors: [2, 6, 1, 0]))
            // 三颗大小不同的光晕叠出"炸开那一下"
            for (i, size) in [0.06, 0.13, 0.24].enumerated() {
                out.append(CelebrationParticle(
                    x: 0.5, y: 0.46, vx: 0, vy: 0, spin: 0,
                    color: i == 2 ? 1 : 2,
                    w: size, h: size,
                    delay: Double(i) * 0.05, life: 0.55 + Double(i) * 0.10,
                    kind: .glow, gravity: 0))
            }
            return out

        case .shockwave:
            // 粒子很少 —— 主要靠背景层的多圈扩散撑起画面
            return spawn(BurstSpec(
                sources: [BurstSpec.Source(x: 0.5, y: 0.46)],
                count: 84,
                speed: 0.80...1.30, angle: 0...(2 * .pi), spread: 0,
                gravity: 0, spin: 0...0,
                w: 0.0035...0.0065, h: 0.0035...0.0065,
                life: 0.75...1.05, delayJitter: 0.02,
                kind: .dot, colors: [4, 7, 2]))

        case .pixels:
            return spawn(BurstSpec(
                sources: [BurstSpec.Source(x: 0.5, y: 0.46)],
                count: 56,
                speed: 0.28...0.80, angle: 0...(2 * .pi), spread: 0.01,
                gravity: 0.85, spin: (-90.0)...90.0,
                w: 0.011...0.026, h: 0.011...0.026,
                life: 1.1...1.6, delayJitter: 0.03,
                kind: .square, colors: [0, 1, 2, 3, 4, 5, 6, 7]))

        case .salvo:
            return spawn(BurstSpec(
                sources: [
                    BurstSpec.Source(x: 0.10, y: 1.02, delay: 0.00),
                    BurstSpec.Source(x: 0.30, y: 1.02, delay: 0.09),
                    BurstSpec.Source(x: 0.50, y: 1.02, delay: 0.18),
                    BurstSpec.Source(x: 0.70, y: 1.02, delay: 0.09),
                    BurstSpec.Source(x: 0.90, y: 1.02, delay: 0.00),
                ],
                count: 22,
                speed: 0.72...1.05, angle: 4.30...5.12, spread: 0.01,
                gravity: 1.25, spin: 0...0,
                w: 0.0030...0.0060, h: 0.0030...0.0060,
                life: 1.4...1.8, delayJitter: 0.04,
                kind: .spark, colors: [0, 2, 3, 4, 5, 6, 7]))
        }
    }

    /// 一排起点（顶部的横向均匀分布）。
    ///
    /// 起点高度**不统一放在画面外**：如果全从 y=-0.08 起步，前 0.6 秒画面是空的，
    /// 学生看到的是"点了没反应"。这里让一部分粒子一开始就在画面上部，
    /// 视觉上像"礼花已经炸开、正飘下来"，而不是"等雨落"。
    private static func topRow(_ n: Int) -> [BurstSpec.Source] {
        (0..<n).map { i in
            BurstSpec.Source(
                x: (Double(i) + Double.random(in: 0.1...0.9)) / Double(max(1, n)),
                y: Double.random(in: -0.14...0.34))
        }
    }

    /// 底部一排起点（上升类用）。同理，一部分已经在画面里了。
    private static func bottomRow(_ n: Int) -> [BurstSpec.Source] {
        (0..<n).map { i in
            BurstSpec.Source(
                x: (Double(i) + Double.random(in: 0.1...0.9)) / Double(max(1, n)),
                y: Double.random(in: 0.45...1.06))
        }
    }

    /// 按配置铺粒子。角度默认均分一整圈，`angularStep` 会让它扭成螺旋。
    private static func spawn(_ s: BurstSpec) -> [CelebrationParticle] {
        var out: [CelebrationParticle] = []
        for src in s.sources {
            for i in 0..<s.count {
                let span = s.angle.upperBound - s.angle.lowerBound
                let base = s.angle.lowerBound + span * (Double(i) / Double(max(1, s.count)))
                let a = base + s.angularStep * Double(i) + Double.random(in: -0.06...0.06)
                let speed = Double.random(in: s.speed)

                var vx = cos(a) * speed
                var vy = sin(a) * speed
                if s.tangential > 0 {
                    // 漩涡：叠一个垂直于半径的速度分量，粒子就会绕着中心转
                    vx += cos(a + .pi / 2) * speed * s.tangential
                    vy += sin(a + .pi / 2) * speed * s.tangential
                }

                out.append(CelebrationParticle(
                    x: src.x + cos(a) * s.radius + Double.random(in: -s.spread...s.spread),
                    y: src.y + sin(a) * s.radius + Double.random(in: -s.spread...s.spread),
                    vx: vx, vy: vy,
                    spin: Double.random(in: s.spin),
                    color: s.colors.isEmpty ? Int.random(in: 0..<palette.count)
                                            : s.colors[i % s.colors.count],
                    w: Double.random(in: s.w),
                    h: Double.random(in: s.h),
                    delay: src.delay + Double.random(in: 0...s.delayJitter),
                    life: Double.random(in: s.life),
                    kind: s.kind,
                    gravity: s.gravity,
                    sway: s.sway,
                    swayRate: s.swayRate))
            }
        }
        return out
    }

    /// 两侧礼炮 + 中心一团烟花
    private static func confettiParticles() -> [CelebrationParticle] {
        var out: [CelebrationParticle] = []

        for (x, dir) in [(0.04, 1.0), (0.96, -1.0)] {
            for _ in 0..<36 {
                let angle = Double.random(in: 54...86) * .pi / 180
                let speed = Double.random(in: 0.85...1.65)
                out.append(CelebrationParticle(
                    x: x + Double.random(in: -0.03...0.03), y: 1.04,
                    vx: cos(angle) * speed * dir, vy: -sin(angle) * speed,
                    spin: Double.random(in: -980...980),
                    color: Int.random(in: 0..<palette.count),
                    w: Double.random(in: 0.010...0.020),
                    h: Double.random(in: 0.012...0.030),
                    delay: Double.random(in: 0...0.14),
                    life: Double.random(in: 1.7...2.3), kind: .ribbon))
            }
        }

        // 中心向四面炸开，掺一些带拖尾的星火
        for i in 0..<46 {
            let angle = Double.random(in: 0..<(2 * .pi))
            let speed = Double.random(in: 0.30...0.98)
            let kind: CelebrationParticle.Kind = i % 6 == 0
                ? .spark
                : (Bool.random() ? .dot : .ribbon)
            let isFlat = kind != .ribbon
            out.append(CelebrationParticle(
                x: 0.5, y: 0.46,
                vx: cos(angle) * speed, vy: sin(angle) * speed,
                spin: Double.random(in: -760...760),
                color: Int.random(in: 0..<palette.count),
                w: Double.random(in: isFlat ? 0.007...0.013 : 0.008...0.016),
                h: Double.random(in: isFlat ? 0.007...0.013 : 0.010...0.024),
                delay: Double.random(in: 0...0.05),
                life: Double.random(in: 1.1...1.8), kind: kind))
        }
        return out
    }

    /// 连环烟花：三处爆点错峰炸开，每处一个主色
    private static func fireworkParticles() -> [CelebrationParticle] {
        var out: [CelebrationParticle] = []
        let bursts: [(x: Double, y: Double, delay: Double, color: Int)] = [
            (0.24, 0.34, 0.00, 0),
            (0.76, 0.26, 0.14, 3),
            (0.52, 0.52, 0.26, 4),
        ]

        for b in bursts {
            for i in 0..<28 {
                let angle = Double(i) / 28 * 2 * .pi + Double.random(in: -0.07...0.07)
                // 速度压在 0.28–0.68：太快会在半秒内飞出画面，看着像"散架"而不是"炸开"
                let speed = Double.random(in: 0.28...0.68)
                // 起点带一点半径，别让三四十个粒子从同一个像素里挤出来（会糊成一团）
                let spread = Double.random(in: 0...0.05)
                out.append(CelebrationParticle(
                    x: b.x + cos(angle) * spread, y: b.y + sin(angle) * spread,
                    vx: cos(angle) * speed, vy: sin(angle) * speed,
                    spin: 0,
                    color: i % 7 == 0 ? (b.color + 2) % palette.count : b.color,
                    w: 0.0048, h: 0.0048,
                    delay: b.delay + Double.random(in: 0...0.03),
                    life: Double.random(in: 1.30...1.90),
                    kind: .spark, gravity: 0.30))
            }
            // 爆心的一圈闪光，让炸点更亮
            for _ in 0..<10 {
                let angle = Double.random(in: 0..<(2 * .pi))
                out.append(CelebrationParticle(
                    x: b.x, y: b.y,
                    vx: cos(angle) * 0.9, vy: sin(angle) * 0.9,
                    spin: 0, color: 2, w: 0.004, h: 0.004,
                    delay: b.delay, life: 0.45, kind: .dot, gravity: 0))
            }
        }
        return out
    }

    /// 星芒绽放：中心 48 条光条放射 + 26 颗星火
    private static func starburstParticles() -> [CelebrationParticle] {
        var out: [CelebrationParticle] = []

        for i in 0..<48 {
            let angle = Double(i) / 48 * 2 * .pi + Double.random(in: -0.03...0.03)
            let speed = Double.random(in: 1.15...1.95)
            out.append(CelebrationParticle(
                x: 0.5, y: 0.46,
                vx: cos(angle) * speed, vy: sin(angle) * speed,
                spin: 0,
                color: i % 3 == 0 ? 2 : (i % 2 == 0 ? 1 : 5),
                w: Double.random(in: 0.0025...0.0045),
                h: Double.random(in: 0.075...0.15),
                delay: Double.random(in: 0...0.05),
                life: Double.random(in: 0.75...1.05),
                kind: .streak, gravity: 0))
        }

        for _ in 0..<26 {
            let angle = Double.random(in: 0..<(2 * .pi))
            let speed = Double.random(in: 0.25...0.70)
            out.append(CelebrationParticle(
                x: 0.5, y: 0.46,
                vx: cos(angle) * speed, vy: sin(angle) * speed,
                spin: Double.random(in: -400...400),
                color: Int.random(in: 0..<palette.count),
                w: 0.007, h: 0.007,
                delay: Double.random(in: 0...0.10),
                life: Double.random(in: 0.8...1.4),
                kind: .spark, gravity: 0.5))
        }
        return out
    }

    /// 冲击光环：环形粒子雨，配三层水波
    private static func ringParticles() -> [CelebrationParticle] {
        var out: [CelebrationParticle] = []
        for i in 0..<56 {
            let angle = Double(i) / 56 * 2 * .pi
            let speed = Double.random(in: 0.55...1.00)
            out.append(CelebrationParticle(
                x: 0.5, y: 0.46,
                vx: cos(angle) * speed, vy: sin(angle) * speed,
                spin: 0, color: i % palette.count,
                w: 0.009, h: 0.009,
                delay: Double.random(in: 0...0.12),
                life: Double.random(in: 1.1...1.6),
                kind: .dot, gravity: 0.55))
        }
        return out
    }

    static func draw(_ theme: CelebrationTheme,
                     particles: [CelebrationParticle],
                     into ctx: inout GraphicsContext,
                     size: CGSize,
                     t: Double) {
        let w = size.width, h = size.height
        guard w > 0, h > 0 else { return }

        // 落定瞬间整体闪一下（用强调色，浅色 / 深色主题下都看得见）
        if t < 0.16 {
            let k = t / 0.16
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(Color.accentColor.opacity((1 - k) * 0.16)))
        }

        // 主题专属的背景层（波 / 光条 / 冲击环 / 新星光球）
        switch theme {
        case .rings:
            drawRings(into: &ctx, size: size, t: t)
        case .starburst:
            drawRays(into: &ctx, size: size, t: t)
        case .confetti:
            drawShockRing(into: &ctx, size: size, t: t)
        case .shockwave:
            drawShockwave(into: &ctx, size: size, t: t)
        case .nova:
            drawNovaCore(into: &ctx, size: size, t: t)
        default:
            break
        }

        for p in particles {
            drawParticle(p, into: &ctx, size: size, t: t)
        }
    }

    private static func drawParticle(_ p: CelebrationParticle,
                                     into ctx: inout GraphicsContext,
                                     size: CGSize,
                                     t: Double) {
        let w = size.width, h = size.height
        let lt = t - p.delay
        guard lt >= 0, lt <= p.life else { return }

        // 横向摆动：雪花、花瓣、气泡靠这条正弦"飘"起来。
        // 只改绘制位置，不动速度模型 —— 否则拖尾方向和实际轨迹会对不上。
        let sway = p.sway > 0 ? sin(lt * p.swayRate * 2 * .pi) * p.sway : 0
        let px = (p.x + p.vx * lt + sway) * w
        let py = (p.y + p.vy * lt + 0.5 * p.gravity * lt * lt) * h
        guard py < h + 70, px > -70, px < w + 70 else { return }

        let fade = lt > p.life * 0.62
            ? max(0, 1 - (lt - p.life * 0.62) / (p.life * 0.38))
            : 1
        let color = palette[p.color % palette.count].opacity(fade)

        switch p.kind {
        case .ribbon:
            let scale = 1 - 0.22 * (lt / p.life)
            let bw = p.w * w * scale, bh = p.h * h * scale
            let path = Path(CGRect(x: -bw / 2, y: -bh / 2, width: bw, height: bh))
                .applying(CGAffineTransform(rotationAngle: p.spin * lt * .pi / 180))
                .applying(CGAffineTransform(translationX: px, y: py))
            ctx.fill(path, with: .color(color))

        case .dot:
            let r = max(0.8, p.w * w)
            ctx.fill(Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                     with: .color(color))

        case .spark:
            let r = max(0.9, p.w * w)
            // 拖尾分两段：远端淡而长（烟），近端亮而短（火）。
            // 只用一条等亮度的线会像"小蝌蚪"，两段才有拖影的感觉。
            var tail = Path()
            tail.move(to: CGPoint(x: px - p.vx * w * 0.085, y: py - p.vy * h * 0.085))
            tail.addLine(to: CGPoint(x: px, y: py))
            ctx.stroke(tail, with: .color(color.opacity(fade * 0.30)), lineWidth: r * 1.1)

            var hot = Path()
            hot.move(to: CGPoint(x: px - p.vx * w * 0.030, y: py - p.vy * h * 0.030))
            hot.addLine(to: CGPoint(x: px, y: py))
            ctx.stroke(hot, with: .color(color.opacity(fade * 0.65)), lineWidth: r * 1.9)

            ctx.fill(Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                     with: .color(color))

        case .streak:
            let len = p.h * min(w, h) * (1 - 0.35 * (lt / p.life))
            let mag = max(0.0001, (p.vx * p.vx + p.vy * p.vy).squareRoot())
            let ux = p.vx / mag, uy = p.vy / mag
            var line = Path()
            line.move(to: CGPoint(x: px, y: py))
            line.addLine(to: CGPoint(x: px + ux * len, y: py + uy * len))
            ctx.stroke(line, with: .color(color),
                       style: StrokeStyle(lineWidth: max(0.8, p.w * w * 2), lineCap: .round))

        case .petal:
            // 花瓣：竖向椭圆，缓慢自转，边缘有一点点亮
            let bw = p.w * w, bh = p.h * h
            let path = Path(ellipseIn: CGRect(x: -bw / 2, y: -bh / 2, width: bw, height: bh))
                .applying(CGAffineTransform(rotationAngle: p.spin * lt * .pi / 180))
                .applying(CGAffineTransform(translationX: px, y: py))
            ctx.fill(path, with: .color(color))

        case .snow:
            // 雪花：三根交叉的线 = 六角
            let r = max(1.2, p.w * w)
            var path = Path()
            for i in 0..<3 {
                let a = Double(i) * .pi / 3 + p.spin * lt * .pi / 180
                path.move(to: CGPoint(x: px - cos(a) * r, y: py - sin(a) * r))
                path.addLine(to: CGPoint(x: px + cos(a) * r, y: py + sin(a) * r))
            }
            ctx.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: max(0.7, r * 0.30), lineCap: .round))

        case .heart:
            let s = max(2.4, p.w * w) * 2.1
            let path = heartShape(cx: px, cy: py, size: s,
                                  rotation: p.spin * lt * .pi / 180)
            ctx.fill(path, with: .color(color))

        case .star:
            let r = max(1.4, p.w * w)
            let path = starShape(cx: px, cy: py, r: r,
                                 rotation: p.spin * lt * .pi / 180)
            ctx.fill(path, with: .color(color))

        case .coin:
            // 金币：绕竖轴翻转（宽度随角度压缩），加一记高光
            let r = max(1.6, p.w * w)
            let flip = abs(cos(p.spin * lt * .pi / 180))
            let bw = r * 2 * (0.22 + 0.78 * flip)
            ctx.fill(Path(ellipseIn: CGRect(x: px - bw / 2, y: py - r, width: bw, height: r * 2)),
                     with: .color(color))
            if bw > r * 0.5 {
                ctx.fill(Path(ellipseIn: CGRect(x: px - bw * 0.20, y: py - r * 0.55,
                                                width: bw * 0.30, height: r * 0.55)),
                         with: .color(.white.opacity(fade * 0.45)))
            }

        case .square:
            let s = max(1.6, p.w * w)
            let path = Path(CGRect(x: -s / 2, y: -s / 2, width: s, height: s))
                .applying(CGAffineTransform(rotationAngle: p.spin * lt * .pi / 180))
                .applying(CGAffineTransform(translationX: px, y: py))
            ctx.fill(path, with: .color(color))

        case .bubble:
            // 气泡：空心圆环 + 左上高光点
            let r = max(1.6, p.w * w)
            ctx.stroke(Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                       with: .color(color.opacity(fade * 0.60)),
                       lineWidth: max(0.8, r * 0.16))
            ctx.fill(Path(ellipseIn: CGRect(x: px - r * 0.42, y: py - r * 0.48,
                                            width: r * 0.34, height: r * 0.34)),
                     with: .color(.white.opacity(fade * 0.65)))

        case .glow:
            // 光晕：径向渐变，外圈完全透明。彗星核、新星的核心都用它。
            let r = max(3, p.w * min(w, h) * (1 + lt / max(0.001, p.life)))
            ctx.fill(Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                     with: .radialGradient(
                        Gradient(colors: [color.opacity(fade * 0.90),
                                          color.opacity(fade * 0.35),
                                          color.opacity(0)]),
                        center: CGPoint(x: px, y: py),
                        startRadius: 0,
                        endRadius: r))
        }
    }

    /// 五角星（10 个顶点交替内外半径）
    private static func starShape(cx: Double, cy: Double, r: Double, rotation: Double) -> Path {
        var p = Path()
        for i in 0..<10 {
            let a = rotation - .pi / 2 + Double(i) * .pi / 5
            let rr = i % 2 == 0 ? r : r * 0.42
            let pt = CGPoint(x: cx + cos(a) * rr, y: cy + sin(a) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    /// 心形（四段三次贝塞尔，从底部尖点出发）
    private static func heartShape(cx: Double, cy: Double, size: Double,
                                   rotation: Double) -> Path {
        var p = Path()
        let s = size
        p.move(to: CGPoint(x: 0, y: s * 0.42))
        p.addCurve(to: CGPoint(x: -s * 0.62, y: -s * 0.14),
                   control1: CGPoint(x: -s * 0.52, y: s * 0.12),
                   control2: CGPoint(x: -s * 0.64, y: -s * 0.38))
        p.addCurve(to: CGPoint(x: 0, y: -s * 0.16),
                   control1: CGPoint(x: -s * 0.58, y: -s * 0.80),
                   control2: CGPoint(x: -s * 0.10, y: -s * 0.72))
        p.addCurve(to: CGPoint(x: s * 0.62, y: -s * 0.14),
                   control1: CGPoint(x: s * 0.10, y: -s * 0.72),
                   control2: CGPoint(x: s * 0.58, y: -s * 0.80))
        p.addCurve(to: CGPoint(x: 0, y: s * 0.42),
                   control1: CGPoint(x: s * 0.64, y: -s * 0.38),
                   control2: CGPoint(x: s * 0.52, y: s * 0.12))
        p.closeSubpath()

        let t = CGAffineTransform(translationX: cx, y: cy)
            .rotated(by: rotation)
        return p.applying(t)
    }

    /// 冲击光环：三层水波，越往外越淡（"冲击光环"主题）
    private static func drawRings(into ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cx = size.width / 2
        let cy = size.height * 0.46
        let base = min(size.width, size.height)

        for delay in [0.0, 0.13, 0.26] {
            let lt = t - delay
            guard lt > 0 else { continue }
            let k = min(1, lt / 0.90)
            let r = base * (0.02 + 0.66 * easeOut(k))
            // 正圆：椭圆环看着像橄榄球，不像冲击波
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                       with: .color(Color.accentColor.opacity((1 - k) * 0.55)),
                       lineWidth: 4 * (1 - k) + 0.8)
        }
    }

    /// 星芒：中心放射的细光条，缓慢自转
    private static func drawRays(into ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cx = size.width / 2
        let cy = size.height * 0.46
        let base = min(size.width, size.height)
        let grow = min(1, t / 0.42)
        let fade = max(0, 1 - t / 1.25)
        guard fade > 0 else { return }

        for i in 0..<20 {
            let a = Double(i) / 20 * 2 * .pi + t * 0.55
            let len = base * (0.10 + 0.34 * grow) * (i % 2 == 0 ? 1 : 0.62)
            let inner = base * 0.02
            var line = Path()
            line.move(to: CGPoint(x: cx + cos(a) * inner, y: cy + sin(a) * inner))
            line.addLine(to: CGPoint(x: cx + cos(a) * len, y: cy + sin(a) * len))
            ctx.stroke(line,
                       with: .color(Color.accentColor.opacity(fade * (i % 2 == 0 ? 0.50 : 0.28))),
                       style: StrokeStyle(lineWidth: i % 2 == 0 ? 2.4 : 1.3, lineCap: .round))
        }
    }

    /// 单层冲击环（彩带主题的点缀，别让中心空着）
    private static func drawShockRing(into ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let limit = 0.46
        guard t < limit else { return }
        let k = t / limit
        let cx = size.width / 2
        let cy = size.height * 0.46
        let r = min(size.width, size.height) * (0.03 + 0.34 * easeOut(k))
        ctx.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                   with: .color(Color.accentColor.opacity((1 - k) * 0.35)),
                   lineWidth: 3 * (1 - k) + 0.6)
    }

    private static func easeOut(_ x: Double) -> Double {
        let v = min(1, max(0, x))
        return 1 - pow(1 - v, 2.4)
    }

    /// 冲击波：五圈错峰扩散，一圈比一圈宽、一圈比一圈淡
    private static func drawShockwave(into ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cx = size.width / 2
        let cy = size.height * 0.46
        let base = min(size.width, size.height)

        for i in 0..<5 {
            let lt = t - Double(i) * 0.075
            guard lt > 0 else { continue }
            let k = min(1, lt / 0.85)
            let r = base * (0.02 + 0.72 * easeOut(k))
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                       with: .color(Color.accentColor.opacity((1 - k) * 0.42)),
                       lineWidth: 5 * (1 - k) + 0.6)
        }
    }

    /// 新星：一声炸开的白光 + 两圈余波
    private static func drawNovaCore(into ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cx = size.width / 2
        let cy = size.height * 0.46
        let base = min(size.width, size.height)

        let flashFade = max(0, 1 - t / 0.5)
        if flashFade > 0 {
            let r = base * (0.06 + 0.30 * easeOut(min(1, t / 0.35)))
            ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                     with: .radialGradient(
                        Gradient(colors: [.white.opacity(flashFade * 0.62),
                                          Color.accentColor.opacity(flashFade * 0.28),
                                          .clear]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0,
                        endRadius: max(1, r)))
        }

        for delay in [0.06, 0.22] {
            let lt = t - delay
            guard lt > 0 else { continue }
            let k = min(1, lt / 1.0)
            let r = base * (0.05 + 0.55 * easeOut(k))
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                       with: .color(Color.accentColor.opacity((1 - k) * 0.38)),
                       lineWidth: 3 * (1 - k) + 0.6)
        }
    }
}

/// 静态一帧的落定特效（离屏渲染核对效果用；界面里走 `ConfettiBurst` 的动画版）
struct ConfettiFrame: View {
    let particles: [CelebrationParticle]
    let t: Double
    var theme: CelebrationTheme = .confetti

    var body: some View {
        Canvas { ctx, size in
            ConfettiBurst.draw(theme, particles: particles, into: &ctx, size: size, t: t)
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// 在卡片上盖一层落定特效（`trigger` 变化时放一次），并裁进圆角里。
    func celebrationOverlay(_ trigger: Int,
                            radius: CGFloat = 24,
                            theme: CelebrationTheme = .confetti,
                            level: EffectLevel = .full) -> some View {
        overlay {
            ConfettiBurst(trigger: trigger, theme: theme, level: level)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    /// 落定瞬间的「弹一下」：轻微放大 + 强调色光晕，随后弹回。
    ///
    /// 和彩带是两回事：彩带管画面热闹，这个管**视线往哪儿看** ——
    /// 老师站在教室后面时，结果那一块得先"动一下"才抓得住眼睛。
    func resultPop(_ trigger: Int) -> some View {
        modifier(ResultPop(trigger: trigger))
    }
}

private struct ResultPop: ViewModifier {
    let trigger: Int

    @State private var popped = false
    @State private var resetTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .scaleEffect(popped ? 1.045 : 1)
            .shadow(color: Color.accentColor.opacity(popped ? 0.55 : 0), radius: popped ? 18 : 0)
            .onChange(of: trigger) { _, _ in
                withAnimation(.spring(response: 0.20, dampingFraction: 0.45)) { popped = true }
                resetTask?.cancel()
                resetTask = Task {
                    try? await Task.sleep(for: .milliseconds(190))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.42)) { popped = false }
                }
            }
            .onDisappear { resetTask?.cancel() }
    }
}


// MARK: - 扑克牌

struct PlayingCardView: View {
    let card: PlayingCard
    var width: CGFloat = 100

    private var tint: Color {
        if card.isJoker { return .primary }
        return card.suit?.isRed == true ? .red : .primary
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(card.rank)
                    .font(.system(size: width * 0.21, weight: .bold, design: .rounded))
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            if let suit = card.suit {
                Image(systemName: suit.symbol)
                    .font(.system(size: width * 0.40))
            } else {
                Text("JOKER")
                    .font(.system(size: width * 0.15, weight: .bold, design: .rounded))
            }
            Spacer(minLength: 0)
            HStack {
                Spacer(minLength: 0)
                Text(card.rank)
                    .font(.system(size: width * 0.21, weight: .bold, design: .rounded))
                    .rotationEffect(.degrees(180))
            }
        }
        .foregroundStyle(tint)
        .padding(width * 0.11)
        .frame(width: width, height: width * 1.42)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.semantic(.controlBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.semantic(.separator), lineWidth: 0.5)
        }
        // 浅色模式下牌面底色和卡片底色都是白的，没有阴影就"浮"在空气里。
        .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
    }
}

// MARK: - 自动换行排布

struct FlowGrid<Item: Hashable, Content: View>: View {
    let items: [Item]
    var spacing: CGFloat = 7
    var minimum: CGFloat = 84
    let content: (Item) -> Content

    init(items: [Item], spacing: CGFloat = 7, minimum: CGFloat = 84,
         @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.spacing = spacing
        self.minimum = minimum
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum), spacing: spacing)],
                  alignment: .leading,
                  spacing: spacing) {
            ForEach(deduped, id: \.self) { content($0) }
        }
    }

    /// 去重（保持原顺序）。
    ///
    /// `ForEach(id: \.self)` 一旦遇到重复元素就会 id 冲突 —— SwiftUI 会丢渲染并打警告。
    /// "已抽记录"来自持久化数据，旧版本或损坏的数据里可能留有重复项，
    /// 所以在入口处兜一下，而不是指望上游永远不重复。
    private var deduped: [Item] {
        var seen = Set<Item>()
        return items.filter { seen.insert($0).inserted }
    }
}
