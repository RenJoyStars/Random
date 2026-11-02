import SwiftUI

// MARK: - 工具专属动效（3.3）
//
// 3.2 之前，十个工具的「过程」长得都一样：数字闪一下、结果跳一下。
// 骰子不该像老虎机，硬币不该像计数器。
//
// 原则只有一条：**照着那个东西在现实里怎么动**。
//   · 硬币绕水平轴翻 → 投影到屏幕上就是「高度压缩 + 换面」
//   · 骰子在桌上滚  → 轻微乱晃 + 落地砸一下
//   · 抽卡是发牌    → 牌背翻成正面的那一下
//   · 猜拳是手      → 预备时上下晃，落定时推出去
//   · 点名是花名册  → 纵向滚轮，一列名字往上走

// MARK: - 老虎机滚轮

/// 一段文字向上滚出、下一段从下方滚入。
///
/// 为什么不用 `contentTransition(.numericText())`：那个只对数字有滚动感，
/// 中文字母会变成淡入淡出；而点名滚动时屏幕上应该是「一列名字往上走」。
struct SlotRoller<Content: View>: View {
    let value: String
    /// 一次切换滚过的距离（≈ 字号的一半最自然）
    var distance: CGFloat = 28
    /// 滚一轮的时长。必须明显短于两次刷新之间的间隔，否则会叠成一团糊。
    var duration: Double = 0.10
    @ViewBuilder var content: (String) -> Content

    @State private var previous: String?
    @State private var progress: Double = 1

    var body: some View {
        ZStack {
            if let previous {
                content(previous)
                    .offset(y: -distance * progress)
                    .opacity(1 - progress)
            }
            content(value)
                .offset(y: distance * (1 - progress))
                .opacity(progress)
        }
        .clipped()
        .onChange(of: value) { old, _ in
            previous = old
            progress = 0
            withAnimation(.easeOut(duration: duration)) { progress = 1 }
        }
    }
}

// MARK: - 硬币

/// 一枚会翻的硬币。
///
/// 翻转用「纵向压缩」而不是 `rotation3DEffect`：绕水平轴转 θ 时，
/// 投影到屏幕上的高度正好是 cos(θ)，宽度不变 —— 压缩才是它在屏幕上的真实样子。
/// 用 3D 旋转还有个副作用：转过 180° 时文字是镜像的，落定后「反」字会反着写。
struct CoinStage: View {
    @Environment(AppModel.self) private var model

    /// 滚动中的连续压缩（模拟越转越慢时的边缘视角）
    @State private var spinSquash: CGFloat = 1
    /// 落地那一下的挤压
    @State private var landSquash: CGFloat = 1
    /// 抛起的高度（负值 = 向上）
    @State private var lift: CGFloat = 0
    /// 落地后左右摇晃
    @State private var wobble: Double = 0
    /// 旋转时扫过币面的反光强度
    @State private var shine: Double = 0
    @State private var task: Task<Void, Never>?

    private var face: Bool? { model.coinIsHeads }
    private var rolling: Bool { model.coinRolling }

    private var label: String {
        guard let face else { return "?" }
        return face ? "正" : "反"
    }

    private var tint: Color {
        // 刻字是压印不是彩色：币面上"正/反"应该是同色调的浮雕。
        // 用蓝色会让它变成一枚"App 图标"，而不是一枚硬币。
        face == nil ? Color(white: 0.55) : Color(white: 0.30)
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // 桌面阴影：硬币飞起来时变小变淡，这是「它离桌面有多高」唯一的线索
                Ellipse()
                    .fill(Color.black.opacity(0.16))
                    .frame(width: 92 + lift * 0.30, height: 10)
                    .blur(radius: 3.5)
                    .offset(y: 78)

                coin
                    .rotationEffect(.degrees(wobble))
                    .scaleEffect(x: 1, y: max(0.04, spinSquash * landSquash), anchor: .center)
                    .offset(y: lift)
            }
            .frame(height: 178)

            StageCaption(text: caption)
        }
        .onChange(of: rolling) { _, isRolling in
            if isRolling { launch() } else { settleDown() }
        }
        .onDisappear { task?.cancel() }
    }

    private var caption: String {
        if rolling { return "硬币在空中翻转…" }
        guard let face else { return "点「抛硬币」开始" }
        return face ? "正面朝上" : "反面朝上"
    }

    private var coin: some View {
        ZStack {
            // 币身：左上打光的银色金属。中心亮斑别太"塑料"，
            // 真硬币的高光是漫开的，不是一个小白点。
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.97), Color(white: 0.84), Color(white: 0.63)],
                        center: UnitPoint(x: 0.36, y: 0.28),
                        startRadius: 8,
                        endRadius: 92)
                )
                .overlay {
                    Circle().strokeBorder(Color.black.opacity(0.16), lineWidth: 1)
                }
                .overlay {
                    // 币缘齿纹
                    Circle()
                        .strokeBorder(Color.white.opacity(0.42),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 3]))
                        .padding(7)
                }
                .overlay {
                    // 内圈压印区：一条浅凹线 + 一条深凹线，
                    // 硬币的「面」和「边」就是这样分开的
                    Circle()
                        .strokeBorder(Color.black.opacity(0.09), lineWidth: 1)
                        .padding(17)
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                        .padding(18.5)
                }

            // 旋转时扫过的一道反光。硬币在转，光斑跟着挪，才有金属感。
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            .white.opacity(0),
                            .white.opacity(0.55 * shine),
                            .white.opacity(0)
                        ]),
                        center: .center,
                        startAngle: .degrees(shine * 420),
                        endAngle: .degrees(shine * 420 + 80))
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            // 压印：字下压一层白、字上盖深灰，读起来像刻进去的
            Text(label)
                .font(.system(size: 50, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .shadow(color: .white.opacity(0.85), radius: 0.5, y: 1)
        }
        .frame(width: 124, height: 124)
        // 结果出来时不再套一圈蓝色描边 —— 那会让它变成一枚「App 图标」。
        // 用一圈散开的柔光表示「这枚已经落定了」，币面本身还是纯金属。
        .shadow(color: Color.accentColor.opacity(face == nil ? 0 : 0.22),
                radius: face == nil ? 0 : 15)
        .shadow(color: .black.opacity(0.16), radius: 10, y: 6)
    }

    private func launch() {
        task?.cancel()
        shine = 0
        wobble = 0
        landSquash = 1

        // 抛起来
        withAnimation(.easeOut(duration: 0.30)) { lift = -78 }
        // 翻转：18 → 100 → 18 的压缩，一轮约 0.2 秒；用 repeatForever，
        // 落定时再打断 —— 这就是硬币在空中越转越慢的那段。
        spinSquash = 1
        withAnimation(.easeInOut(duration: 0.20).repeatForever(autoreverses: true)) {
            spinSquash = 0.16
        }
        withAnimation(.linear(duration: 0.9)) { shine = 1 }

        task = Task {
            try? await Task.sleep(for: .seconds(0.30))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.34)) { lift = 0 }
        }
    }

    private func settleDown() {
        task?.cancel()

        // 打断 repeatForever：直接覆盖成 1，不留残余动画
        withAnimation(.linear(duration: 0.06)) { spinSquash = 1 }
        shine = 0
        lift = 0

        // 落地挤压 + 回弹
        landSquash = 0.82
        withAnimation(.interpolatingSpring(stiffness: 320, damping: 8)) { landSquash = 1 }

        // 摇晃三下就停：真实硬币落地会晃，但不会一直晃
        task = Task {
            for amp in [4.5, -3.4, 2.4, -1.5, 0.0] {
                withAnimation(.easeInOut(duration: 0.085)) { wobble = amp }
                try? await Task.sleep(for: .milliseconds(85))
                guard !Task.isCancelled else { return }
            }
        }
    }
}

// MARK: - 骰子

/// 会滚、会砸的骰子组。
struct DiceStage: View {
    let values: [Int]
    let faces: Int
    let rolling: Bool

    @State private var thump: CGFloat = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 50, paused: !rolling)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 14) {
                ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                    DieFace(value: v, faces: faces)
                        // 每颗骰子的相位错开，才不会像齐步走
                        .offset(x: rolling ? sin(t * 17 + Double(i) * 2.1) * 5.5 : 0,
                                y: rolling ? cos(t * 23 + Double(i) * 1.4) * 4.5 : 0)
                        .rotationEffect(.degrees(rolling ? sin(t * 15 + Double(i) * 1.7) * 11 : 0))
                        .blur(radius: rolling ? 0.7 : 0)
                        .scaleEffect(thump)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onChange(of: rolling) { _, r in
            guard !r else { return }
            // 落桌：放大一下再弹回去
            thump = 1.15
            withAnimation(.interpolatingSpring(stiffness: 320, damping: 9)) { thump = 1 }
        }
    }
}

// MARK: - 抽卡

/// 牌背：深色底 + 细网格 + 内框，像一副真牌。
struct CardBack: View {
    var width: CGFloat = 100

    var body: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(Color.accentColor.opacity(0.88))
            .overlay {
                GeometryReader { geo in
                    let step: CGFloat = 7
                    Path { p in
                        var x: CGFloat = -geo.size.height
                        while x < geo.size.width + geo.size.height {
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x + geo.size.height, y: geo.size.height))
                            x += step
                        }
                    }
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.5)
                    .padding(7)
            }
            .overlay {
                Image(systemName: "suit.spade.fill")
                    .font(.system(size: width * 0.26))
                    .foregroundStyle(Color.white.opacity(0.9))
            }
            .frame(width: width, height: width * 1.42)
            .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
    }
}

/// 抽卡舞台：滚动时是一叠牌背，落定时逐张翻成正面。
struct CardStage: View {
    let cards: [PlayingCard]
    /// 滚动中要显示几张牌背（= 这次要抽几张）
    let count: Int
    let rolling: Bool
    /// 第几轮。每轮都重新播一次翻牌 —— 否则第二次抽牌会「凭空出现」。
    var round: Int = 0
    var width: CGFloat = 90

    private var shownWidth: CGFloat { cards.count > 4 ? 64 : width }

    var body: some View {
        Group {
            if rolling || cards.isEmpty {
                // 洗牌：几张牌背错开一点，轻轻晃
                HStack(spacing: 10) {
                    ForEach(0..<max(1, min(count, 10)), id: \.self) { i in
                        CardBack(width: shownWidth)
                            .rotationEffect(.degrees(Double(i - count / 2) * 1.2))
                            .offset(y: CGFloat(i % 2 == 0 ? -3 : 3))
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            } else {
                HStack(spacing: 10) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                        FlippingCard(card: card, width: shownWidth,
                                     delay: Double(i) * 0.065)
                            .id(round &* 100 &+ i)
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.16), value: rolling)
    }
}

/// 一张从背面翻到正面的牌。
///
/// 用两段「立起来 —— 展开」而不是旋转角度：
/// 水平方向压到 0 的时候，观众看到的就是牌侧对着自己，
/// 这个时刻换面，任何角度都不会露馅（也不需要拿到动画中间值）。
private struct FlippingCard: View {
    let card: PlayingCard
    let width: CGFloat
    let delay: Double

    @State private var flipped = false
    @State private var squashX: CGFloat = 1

    var body: some View {
        ZStack {
            if flipped {
                PlayingCardView(card: card, width: width)
            } else {
                CardBack(width: width)
            }
        }
        .scaleEffect(x: max(0.03, squashX), y: 1)
        .onAppear {
            squashX = 1
            withAnimation(.easeIn(duration: 0.11).delay(delay)) { squashX = 0.03 }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.11) {
                flipped = true
                withAnimation(.easeOut(duration: 0.13)) { squashX = 1 }
            }
        }
    }
}

// MARK: - 猜拳

/// 出拳按钮。
///
/// 原来三个都是 `.borderedProminent`，一屏三个同样重的蓝块，
/// 比上面正在出拳的两只手还抢眼。原生 macOS 里强调色只给「这一屏唯一要做的事」，
/// 这里三选一不是唯一 —— 所以平时灰底细边，指针移上去才亮。
struct MoveButton: View {
    let move: RPS
    let disabled: Bool
    let action: () -> Void

    @State private var hovering = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(move.glyph).font(.system(size: 32))
                Text(move.title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background {
                shape.fill(hovering
                           ? Color.accentColor.opacity(0.12)
                           : Color.semantic(.controlBackground))
            }
            .overlay {
                shape.strokeBorder(hovering
                                   ? Color.accentColor.opacity(0.55)
                                   : Color.semantic(.separator),
                                   lineWidth: hovering ? 1 : 0.5)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .onHover { hovering = $0 }
    }
}

/// 猜拳舞台：两只手 + 胜负。
///
/// 「手」不用图标 —— 图标是符号，emoji 是手。学生一眼认的是那个 ✊。
struct RPSStage: View {
    let myMove: RPS?
    let aiMove: RPS?
    let rolling: Bool
    let resultText: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 0) {
                HandColumn(title: "你", move: myMove, rolling: rolling,
                           highlight: true, swingPhase: 0)
                Text("VS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 52)
                HandColumn(title: "电脑", move: aiMove, rolling: rolling,
                           highlight: false, swingPhase: .pi)
            }

            Text(resultText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(resultText == "你赢了" ? Color.green
                                 : resultText == "你输了" ? Color.secondary
                                 : Color.primary)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.18), value: resultText)
        }
    }
}

private struct HandColumn: View {
    let title: String
    let move: RPS?
    let rolling: Bool
    let highlight: Bool
    let swingPhase: Double

    @State private var push: CGFloat = 1

    var body: some View {
        VStack(spacing: 7) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TimelineView(.animation(minimumInterval: 1.0 / 50, paused: !rolling)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let swing = rolling ? sin(t * 11 + swingPhase) : 0

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(highlight
                              ? Color.accentColor.opacity(0.13)
                              : Color.primary.opacity(0.05))

                    if let move {
                        VStack(spacing: 1) {
                            Text(move.glyph)
                                .font(.system(size: 40))
                            Text(move.title)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .offset(y: swing * 7)
                        .rotationEffect(.degrees(swing * 5))
                    } else {
                        Text("?")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.quaternary)
                            .offset(y: swing * 5)
                    }
                }
                .frame(height: 108)
                .scaleEffect(push)
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: rolling) { _, r in
            guard !r else { return }
            // 出拳：手往前推一下。电脑稍慢半拍，才有「同时出」的错觉。
            let d = highlight ? 0.0 : 0.09
            push = 1.18
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55).delay(d)) { push = 1 }
        }
    }
}

// MARK: - 滚轮文字

/// 大号滚动数字。复刻 `BigNumber` 的排版，但每次换值都是「往上滚一格」，
/// 而不是原地淡入淡出 —— 计数器/老虎机的手感全在这个位移上。
struct RollingNumber: View {
    let text: String
    var size: CGFloat = 132
    var weight: Font.Weight = .bold
    var tint: Color = .primary

    var body: some View {
        SlotRoller(value: text, distance: size * 0.30, duration: 0.085) { v in
            Text(v)
                .font(.system(size: size, weight: weight, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.22)
                .foregroundStyle(tint)
        }
        .frame(height: size * 1.24)
    }
}

/// 「07 号」：数字滚动，「号」字不动。号字跟着滚会显得整块在抖。
struct RollingNumberUnit: View {
    let text: String
    var size: CGFloat = 132

    var body: some View {
        // 不能用 .firstTextBaseline：SlotRoller 为了裁切给了固定高度，
        // 这个容器没有文字基线，对齐会失效（「号」会被顶到下面去）。
        // 改用底对齐 + 一点补偿 —— 数字的视觉下沿比行框高一点。
        HStack(alignment: .bottom, spacing: 3) {
            SlotRoller(value: text, distance: size * 0.30, duration: 0.085) { v in
                Text(v)
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.22)
            }
            .frame(height: size * 1.24)

            Text("号")
                .font(.system(size: size * 0.30, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, size * 0.15)
        }
    }
}

/// 姓名的一行：滚动时一个个名字往上走，就是花名册被快速翻过去的样子。
struct RollingNames: View {
    let text: String
    var size: CGFloat = 22
    var tint: Color = .accentColor

    var body: some View {
        SlotRoller(value: text, distance: size * 0.85, duration: 0.085) { v in
            Text(v)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(height: size * 1.5)
    }
}


// MARK: - 随机颜色

/// 颜色舞台：色块落定时向外扩一圈同色光环。
struct ColorStage: View {
    let color: Color
    let hex: String
    let rgbText: String
    let hsbText: String
    let rolling: Bool
    /// 每换一次颜色 +1，用来触发脉冲
    let pulse: Int

    @State private var ring: CGFloat = 0
    @State private var breathe: CGFloat = 1

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // 外扩的光环：只在落定那一刻出现
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(color.opacity(0.55 * (1 - ring)), lineWidth: 2)
                    .frame(height: 108)
                    .frame(maxWidth: 320)
                    .scaleEffect(x: 1 + ring * 0.10, y: 1 + ring * 0.28)
                    .opacity(ring > 0 && ring < 1 ? 1 : 0)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color)
                    .frame(height: 108)
                    .frame(maxWidth: 320)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
                    .scaleEffect(breathe)
                    .shadow(color: color.opacity(rolling ? 0.34 : 0.16),
                            radius: rolling ? 10 : 5, y: 2)
            }
            .frame(height: 118)

            SlotRoller(value: hex, distance: 16, duration: 0.09) { text in
                Text(text)
                    .font(.system(size: 25, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)
            }
            .frame(height: 32)

            StageCaption(text: "\(rgbText)　·　\(hsbText)")
        }
        .onChange(of: rolling) { _, r in
            if r {
                // 抽的时候色块轻轻呼吸，像还在调
                withAnimation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true)) {
                    breathe = 1.035
                }
            } else {
                withAnimation(.easeOut(duration: 0.14)) { breathe = 1 }
            }
        }
        .onChange(of: pulse) { _, _ in
            guard !rolling else { return }
            ring = 0
            withAnimation(.easeOut(duration: 0.55)) { ring = 1 }
        }
    }
}

// MARK: - 随机分组

/// 分组洗牌：滚动时是几摞牌在桌上被来回推着分。
///
/// 分组和「随机数字」的差别就在这个过程上 —— 老师看的是**堆**，不是数。
/// 所以滚动时每张卡里画的是一叠错位滑动的牌背，上面顶着正在换的名字，
/// 落定后由外层换成真正的组员名单。
struct GroupShuffleStage: View {
    @Environment(AppModel.self) private var model

    private var pileCount: Int {
        max(1, model.groups.isEmpty ? model.plannedGroupCount : model.groups.count)
    }

    private func sample(_ i: Int) -> String {
        guard i < model.groups.count, let no = model.groups[i].first else { return "　" }
        let name = model.name(no: no) ?? "\(no)"
        return model.groupShowNumbers ? "\(model.fmtNo(no))　\(name)" : name
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)],
                  alignment: .leading, spacing: 10) {
            ForEach(0..<pileCount, id: \.self) { i in
                ShufflingPile(index: i, label: sample(i))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 一摞正在洗的牌。
private struct ShufflingPile: View {
    let index: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("第 \(index + 1) 组")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Spacer(minLength: 4)
                Text("洗牌中")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // 名字从这摞牌里一张张被翻出来
            SlotRoller(value: label, distance: 15, duration: 0.09) { v in
                Text(v)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 17)

            // 三张牌背来回错开，就是手在桌上推牌的样子
            TimelineView(.animation(minimumInterval: 1.0 / 40)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                // 三张牌**压在一起**才对 —— 之前留 2pt 间隔，看着是三个蓝方块。
                // 负间距让它们只露出边缘，加上一点点各自的角度，就是一叠牌。
                HStack(spacing: -11) {
                    ForEach(0..<3, id: \.self) { k in
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(Color.accentColor.opacity(0.62 - Double(k) * 0.10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.8)
                            }
                            .frame(width: 21, height: 30)
                            .rotationEffect(.degrees(Double(k - 1) * 5))
                            .offset(x: sin(t * 5.5 + Double(index) * 1.3 + Double(k) * 0.8) * 3,
                                    y: cos(t * 4.2 + Double(k)) * 1.2)
                    }
                }
                .frame(height: 34, alignment: .leading)
            }
        }
        .padding(10)
        // 和落定后的组卡差不多高：不然洗牌一结束，卡片会整块往下掉一截
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        }
    }
}

// MARK: - 随机顺序

/// 顺序舞台：滚动时前三位一起往上滚，落定后定格在「第 1 位」。
///
/// 只滚一个名字看不出这是「排队」；滚三个，老师就知道是在排顺序。
struct SequenceStage: View {
    @Environment(AppModel.self) private var model
    /// 滚动时露几位
    var preview: Int = 3

    private var scale: CGFloat { model.effectiveStageScale }

    private func name(at i: Int) -> String {
        guard i < model.sequenceResult.count else { return "　" }
        let no = model.sequenceResult[i]
        return model.name(no: no) ?? "\(no) 号"
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(model.sequenceRolling ? "正在打乱…" : "第 1 位")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)

            if model.sequenceRolling {
                // 洗牌中：前三位并排滚。
                //
                // 名字必须装进**定宽**框再居中 —— 否则每行宽度随名字长短变化，
                // VStack 的居中对齐会让三行名字的起点各偏一点，看着像没对齐。
                VStack(spacing: 4) {
                    ForEach(0..<min(preview, max(1, model.sequenceResult.count)), id: \.self) { i in
                        HStack(spacing: 8) {
                            Text("\(i + 1)")
                                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 14, alignment: .trailing)
                            SlotRoller(value: name(at: i), distance: 20, duration: 0.09) { v in
                                Text(v)
                                    .font(.system(size: i == 0 ? 28 : 17,
                                                  weight: i == 0 ? .bold : .regular))
                                    .foregroundStyle(i == 0 ? Color.accentColor : Color.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(width: 168, alignment: .leading)
                            }
                            .frame(height: i == 0 ? 36 : 22)
                        }
                    }
                }
            } else {
                Text(name(at: 0))
                    .font(.system(size: 46 * scale, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .resultPop(model.celebration)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.16), value: model.sequenceRolling)
    }
}

// MARK: - 是或否

/// 是或否：滚动时整块字左右摇摆，像下不了决心；落定才归正。
///
/// 这个工具本来没有实物可演，最容易和「随机数字」撞脸。
/// 摇摆是「犹豫」的肢体语言，一摇摆就分得开了。
struct YesNoStage: View {
    let text: String
    let positive: Bool
    let rolling: Bool
    var size: CGFloat = 124

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 45, paused: !rolling)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            // 摆幅随拍子微微变化，规矩的正弦看着像机器
            let wobble = rolling
                ? sin(t * 8.4) * 7.5 + sin(t * 3.7) * 2
                : 0

            RollingNumber(text: text, size: size,
                          tint: positive ? Color.green : Color.red)
                .rotationEffect(.degrees(wobble))
                .offset(x: rolling ? sin(t * 5.1) * 10 : 0)
        }
        .animation(.easeOut(duration: 0.18), value: rolling)
    }
}

// MARK: - 点名扫描

/// 点名时扫过舞台的一条光带。
///
/// 点名和「随机数字」最容易撞车 —— 都是滚数字。区别在这条扫描线：
/// 它像老师的手指在花名册上一行行划过去，落定就停住收掉。
struct SpotlightSweep: View {
    let active: Bool
    @Environment(\.colorScheme) private var scheme

    /// 深色底上必须更亮才看得见；浅色底上反而要收着，不然像划痕。
    private var lineOpacity: Double { scheme == .dark ? 0.46 : 0.22 }
    private var glowOpacity: Double { scheme == .dark ? 0.30 : 0.13 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 45, paused: !active)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            // 0…1 来回扫，不用取模，免得接缝处跳一下
            let sweep = (sin(t * 2.6) + 1) / 2
            GeometryReader { geo in
                let w = geo.size.width
                let x = w * sweep
                // 不用整条渐变色带 —— 之前 36% 宽的一条铺上去，
                // 看着像卡片右半边被染了色，不像在「扫」。
                // 现在只在线的两侧放一小团柔光，加一条 1.5pt 的线。
                ZStack(alignment: .leading) {
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [Color.accentColor.opacity(glowOpacity), .clear],
                                center: .center, startRadius: 0, endRadius: 46)
                        )
                        .frame(width: 150, height: geo.size.height * 0.92)
                        .offset(x: x - 75)

                    Rectangle()
                        .fill(Color.accentColor.opacity(lineOpacity))
                        .frame(width: 1.5)
                        .offset(x: x)
                }
            }
        }
        .opacity(active ? 1 : 0)
        .animation(.easeOut(duration: 0.20), value: active)
        .allowsHitTesting(false)
    }
}
