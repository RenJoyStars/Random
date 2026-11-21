import SwiftUI

// MARK: - 工具专属 3D 立体动效（3.5+）
//
// 原则：**照着真实世界里的物理质感与 3D 透视去动**，同时可通过 `model.motion3D`
// 一键在「3D 景深立体」与「轻量 2D」之间平滑切换，兼顾教室老电脑投影性能。
//
//   · 滚筒文字    → X 轴 3D 圆柱翻转（翻页钟/滚筒手感）
//   · 硬币        → 3D 金属厚度边 + 无镜像抛物线翻转 + 3 种金属材质 + 动态扫光
//   · 骰子        → X/Y/Z 三轴 3D 立体翻滚 + 4 种材质皮肤 + 落桌投影弹跳
//   · 抽卡        → 3D 弧形扇面洗牌 + 真 Y 轴 0°→90°/-90°→0° 无镜像立体翻牌 + 4 款牌背
//   · 猜拳        → 3D 俯仰蓄力 + 出拳冲刺光环
//   · 颜色        → 3D 悬停倾角色卡 + 双层扩散光环
//   · 分组 / 顺序 → 3D 桌面牌堆洗牌与立体排名揭晓
//   · 是或否      → 3D 天平举棋不定摇摆

// MARK: - 3D 滚筒文字

/// 一段文字沿 3D 滚筒向上翻出、下一段从下方翻入。
struct SlotRoller<Content: View>: View {
    @Environment(AppModel.self) private var model
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
                    .rotation3DEffect(
                        .degrees(model.motion3D ? -34 * progress : 0),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.55
                    )
            }
            content(value)
                .offset(y: distance * (1 - progress))
                .opacity(progress)
                .rotation3DEffect(
                    .degrees(model.motion3D ? 34 * (1 - progress) : 0),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.55
                )
        }
        .clipped()
        .onChange(of: value) { old, _ in
            previous = old
            progress = 0
            withAnimation(.easeOut(duration: duration)) { progress = 1 }
        }
    }
}

// MARK: - 3D 金属硬币

/// 一枚带 3D 金属厚边与三种材质皮肤的硬币。
///
/// 翻转主体沿用无镜像的「纵向压缩 cos(θ) + 换面」，并在 3D 模式下叠加多层金属侧边厚度
/// 与微倾角透视，既呈现真实 3D 金属质感，又绝不会出现文字镜像反写。
struct CoinStage: View {
    @Environment(AppModel.self) private var model

    @State private var spinSquash: CGFloat = 1
    @State private var landSquash: CGFloat = 1
    @State private var lift: CGFloat = 0
    @State private var wobble: Double = 0
    @State private var tiltX: Double = 0
    @State private var shine: Double = 0
    @State private var task: Task<Void, Never>?

    private var face: Bool? { model.coinIsHeads }
    private var rolling: Bool { model.coinRolling }

    private var label: String {
        guard let face else { return "?" }
        return face ? model.coinHeadsLabel : model.coinTailsLabel
    }

    private var palette: (light: Color, mid: Color, dark: Color, edge: Color, ink: Color, glow: Color) {
        switch model.coinStyle {
        case .gold:
            return (
                Color(red: 1.00, green: 0.93, blue: 0.64),
                Color(red: 0.92, green: 0.72, blue: 0.22),
                Color(red: 0.64, green: 0.44, blue: 0.08),
                Color(red: 0.52, green: 0.34, blue: 0.05),
                Color(red: 0.42, green: 0.25, blue: 0.02),
                Color(red: 0.95, green: 0.72, blue: 0.16)
            )
        case .bronze:
            return (
                Color(red: 0.96, green: 0.80, blue: 0.64),
                Color(red: 0.78, green: 0.50, blue: 0.30),
                Color(red: 0.48, green: 0.27, blue: 0.14),
                Color(red: 0.38, green: 0.20, blue: 0.10),
                Color(red: 0.30, green: 0.15, blue: 0.07),
                Color(red: 0.82, green: 0.50, blue: 0.26)
            )
        case .silver:
            return (
                Color(white: 0.97),
                Color(white: 0.84),
                Color(white: 0.62),
                Color(white: 0.46),
                face == nil ? Color(white: 0.52) : Color(white: 0.28),
                model.resolvedStageAccent
            )
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // 桌面动态投影：硬币抛高时投影缩小淡化，落地时收实
                Ellipse()
                    .fill(Color.black.opacity(max(0.06, 0.20 + Double(lift) * 0.0014)))
                    .frame(width: max(46, 98 + lift * 0.38), height: 11)
                    .blur(radius: 4)
                    .offset(y: 78)

                coinBody
                    .rotationEffect(.degrees(wobble))
                    .rotation3DEffect(
                        .degrees(model.motion3D ? tiltX : 0),
                        axis: (x: 1, y: 0.18, z: 0),
                        perspective: 0.55
                    )
                    .scaleEffect(x: 1, y: max(0.05, spinSquash * landSquash), anchor: .center)
                    .offset(y: lift)
            }
            .frame(height: 184)

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
        return face ? "结果：\(model.coinHeadsLabel)" : "结果：\(model.coinTailsLabel)"
    }

    private var coinBody: some View {
        let p = palette
        return ZStack {
            // 3D 金属厚度侧边（多层错位圆盘叠出真实硬币边缘厚度）
            if model.motion3D {
                ForEach((1...4).reversed(), id: \.self) { layer in
                    Circle()
                        .fill(p.edge.opacity(0.92 - Double(layer) * 0.08))
                        .frame(width: 126, height: 126)
                        .offset(y: CGFloat(layer) * 1.6)
                }
            }

            // 币面本体
            Circle()
                .fill(
                    RadialGradient(
                        colors: [p.light, p.mid, p.dark],
                        center: UnitPoint(x: 0.34, y: 0.26),
                        startRadius: 8,
                        endRadius: 94)
                )
                .overlay {
                    Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 1)
                }
                .overlay {
                    // 币缘齿纹
                    Circle()
                        .strokeBorder(Color.white.opacity(0.45),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 3]))
                        .padding(7)
                }
                .overlay {
                    // 内圈压印槽
                    Circle()
                        .strokeBorder(Color.black.opacity(0.11), lineWidth: 1)
                        .padding(17)
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.38), lineWidth: 0.8)
                        .padding(18.5)
                }

            // 旋转时扫过的金属高光带
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            .white.opacity(0),
                            .white.opacity(0.60 * shine),
                            .white.opacity(0)
                        ]),
                        center: .center,
                        startAngle: .degrees(shine * 440),
                        endAngle: .degrees(shine * 440 + 85))
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            // 压印浮雕文字（支持 1~3 字自定义文案，自动缩放防溢出）
            Text(label)
                .font(.system(size: label.count > 1 ? 34 : 50, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .padding(.horizontal, 20)
                .foregroundStyle(p.ink)
                .shadow(color: .white.opacity(0.80), radius: 0.5, y: 1)
        }
        .frame(width: 126, height: 126)
        .shadow(color: p.glow.opacity(face == nil ? 0 : 0.28),
                radius: face == nil ? 0 : 18)
        .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
    }

    private func launch() {
        task?.cancel()
        shine = 0
        wobble = 0
        landSquash = 1
        tiltX = 0

        withAnimation(.easeOut(duration: 0.30)) {
            lift = -82
            tiltX = 24
        }
        spinSquash = 1
        withAnimation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true)) {
            spinSquash = 0.14
        }
        withAnimation(.linear(duration: 0.9)) { shine = 1 }

        task = Task {
            try? await Task.sleep(for: .seconds(0.30))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.34)) {
                lift = 0
                tiltX = -10
            }
        }
    }

    private func settleDown() {
        task?.cancel()

        withAnimation(.linear(duration: 0.06)) { spinSquash = 1 }
        shine = 0
        lift = 0

        landSquash = 0.80
        withAnimation(.interpolatingSpring(stiffness: 320, damping: 8)) {
            landSquash = 1
            tiltX = 0
        }

        task = Task {
            for amp in [5.0, -3.6, 2.2, -1.2, 0.0] {
                withAnimation(.easeInOut(duration: 0.08)) { wobble = amp }
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { return }
            }
        }
    }
}

// MARK: - 3D 立体骰子

/// 会滚、会砸、带三轴 3D 翻滚与桌面投影的骰子组。
struct DiceStage: View {
    @Environment(AppModel.self) private var model
    let values: [Int]
    let faces: Int
    let rolling: Bool

    @State private var thump: CGFloat = 1
    @State private var settleTilt: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 50, paused: !rolling)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: values.count > 5 ? 10 : 16) {
                ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                    let phase = Double(i) * 1.9
                    let bounceY = rolling ? abs(sin(t * 14 + phase)) * -16 : 0
                    let rx = rolling && model.motion3D ? sin(t * 16 + phase) * 38 : settleTilt
                    let ry = rolling && model.motion3D ? cos(t * 19 + phase * 1.3) * 42 : 0
                    let rz = rolling ? sin(t * 13 + phase) * 14 : 0

                    VStack(spacing: 6) {
                        DieFace(value: v, faces: faces, style: model.diceStyle)
                            .rotationEffect(.degrees(rz))
                            .rotation3DEffect(.degrees(rx), axis: (x: 1, y: 0, z: 0), perspective: 0.52)
                            .rotation3DEffect(.degrees(ry), axis: (x: 0, y: 1, z: 0), perspective: 0.52)
                            .offset(x: rolling ? sin(t * 17 + phase) * 5.0 : 0, y: bounceY)
                            .blur(radius: rolling ? 0.5 : 0)
                            .scaleEffect(thump)

                        // 动态桌面投影
                        Ellipse()
                            .fill(Color.black.opacity(rolling ? 0.10 : 0.18))
                            .frame(width: max(28, 52 + bounceY * 0.9), height: 6)
                            .blur(radius: 2.5)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
        .onChange(of: rolling) { _, r in
            guard !r else { return }
            thump = 1.16
            settleTilt = model.motion3D ? -14 : 0
            withAnimation(.interpolatingSpring(stiffness: 320, damping: 9)) {
                thump = 1
                settleTilt = 0
            }
        }
    }
}

// MARK: - 3D 抽卡与扇形发牌

/// 牌背：4 款高级主题皮肤（经典蓝 / 皇家红 / 祖母绿 / 暗夜金），带细密斜纹与双层金线框。
struct CardBack: View {
    var width: CGFloat = 100
    var style: CardBackStyle = .classicBlue

    private var colors: (top: Color, bottom: Color, foil: Color, line: Color) {
        switch style {
        case .classicBlue:
            return (Color(red: 0.16, green: 0.44, blue: 0.92),
                    Color(red: 0.08, green: 0.24, blue: 0.64),
                    Color.white.opacity(0.92),
                    Color.white.opacity(0.24))
        case .crimson:
            return (Color(red: 0.78, green: 0.14, blue: 0.22),
                    Color(red: 0.46, green: 0.06, blue: 0.12),
                    Color(red: 1.00, green: 0.88, blue: 0.58),
                    Color(red: 1.00, green: 0.86, blue: 0.52).opacity(0.25))
        case .emerald:
            return (Color(red: 0.08, green: 0.54, blue: 0.38),
                    Color(red: 0.04, green: 0.30, blue: 0.22),
                    Color(red: 0.95, green: 0.90, blue: 0.68),
                    Color.white.opacity(0.22))
        case .midnightGold:
            return (Color(red: 0.18, green: 0.19, blue: 0.26),
                    Color(red: 0.09, green: 0.10, blue: 0.15),
                    Color(red: 0.96, green: 0.78, blue: 0.36),
                    Color(red: 0.96, green: 0.78, blue: 0.36).opacity(0.24))
        }
    }

    var body: some View {
        let c = colors
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        shape
            .fill(LinearGradient(colors: [c.top, c.bottom], startPoint: .topLeading, endPoint: .bottomTrailing))
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
                    .stroke(c.line, lineWidth: 0.9)
                }
                .clipShape(shape)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(c.foil.opacity(0.60), lineWidth: 0.8)
                    .padding(6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(c.foil.opacity(0.30), lineWidth: 0.5)
                    .padding(9)
            }
            .overlay {
                Image(systemName: "suit.spade.fill")
                    .font(.system(size: width * 0.26))
                    .foregroundStyle(c.foil)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            }
            .overlay {
                shape.strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
            }
            .frame(width: width, height: width * 1.42)
            .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
    }
}

/// 3D 抽卡舞台：洗牌时扇形牌背错落起伏，落定时逐张真 3D Y 轴无镜像翻转揭晓。
struct CardStage: View {
    @Environment(AppModel.self) private var model
    let cards: [PlayingCard]
    let count: Int
    let rolling: Bool
    var round: Int = 0
    var width: CGFloat = 90

    private var shownWidth: CGFloat {
        let n = rolling ? count : cards.count
        if n > 6 { return 56 }
        if n > 4 { return 68 }
        return width
    }

    var body: some View {
        Group {
            if rolling || cards.isEmpty {
                TimelineView(.animation(minimumInterval: 1.0 / 45, paused: !rolling)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    let n = max(1, min(count, 10))
                    let mid = Double(n - 1) / 2.0
                    HStack(spacing: n > 5 ? -10 : 8) {
                        ForEach(0..<n, id: \.self) { i in
                            let delta = Double(i) - mid
                            let wave = rolling ? sin(t * 10 + Double(i) * 0.8) : 0
                            CardBack(width: shownWidth, style: model.cardBackStyle)
                                .rotationEffect(.degrees(delta * (n > 3 ? 3.2 : 2.0) + wave * 2.5))
                                .rotation3DEffect(
                                    .degrees(model.motion3D ? delta * 6 + wave * 10 : 0),
                                    axis: (x: 0.15, y: 1, z: 0),
                                    perspective: 0.55
                                )
                                .offset(y: CGFloat(abs(delta) * 2.5) + CGFloat(wave * 5))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .transition(.opacity)
            } else {
                let n = cards.count
                let mid = Double(n - 1) / 2.0
                HStack(spacing: n > 5 ? 6 : 10) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                        let delta = Double(i) - mid
                        FlippingCard(card: card,
                                     width: shownWidth,
                                     backStyle: model.cardBackStyle,
                                     motion3D: model.motion3D,
                                     fanAngle: n > 1 ? delta * (n > 4 ? 2.2 : 3.0) : 0,
                                     delay: Double(i) * 0.07)
                            .offset(y: CGFloat(abs(delta) * 2.0))
                            .id(round &* 100 &+ i)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.16), value: rolling)
    }
}

/// 一张带真 3D Y 轴透视翻转的扑克牌（0°→90° 背面隐去，-90°→0° 正面展平，绝不镜像）。
private struct FlippingCard: View {
    let card: PlayingCard
    let width: CGFloat
    let backStyle: CardBackStyle
    let motion3D: Bool
    let fanAngle: Double
    let delay: Double

    @State private var flipped = false
    @State private var angle: Double = 0
    @State private var lift: CGFloat = 0
    @State private var hovering = false
    @State private var flipTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if flipped {
                PlayingCardView(card: card, width: width)
            } else {
                CardBack(width: width, style: backStyle)
            }
        }
        .rotation3DEffect(
            .degrees(motion3D ? angle : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.48
        )
        .scaleEffect(x: motion3D ? 1 : max(0.03, abs(cos(angle * .pi / 180))), y: 1)
        .rotationEffect(.degrees(hovering ? 0 : fanAngle))
        .offset(y: lift + (hovering ? -6 : 0))
        .scaleEffect(hovering ? 1.06 : 1.0)
        .zIndex(hovering ? 10 : 0)
        .animation(.snappy(duration: 0.18), value: hovering)
        .onHover { hovering = $0 }
        .onAppear {
            flipTask?.cancel()
            flipped = false
            angle = 0
            lift = 0
            withAnimation(.easeIn(duration: 0.13).delay(delay)) {
                angle = 90
                lift = -12
            }
            flipTask = Task {
                try? await Task.sleep(for: .seconds(delay + 0.13))
                guard !Task.isCancelled else { return }
                flipped = true
                angle = -90
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    angle = 0
                    lift = 0
                }
            }
        }
        .onDisappear { flipTask?.cancel() }
    }
}

// MARK: - 3D 猜拳

/// 出拳按钮：原生灰底细边，悬停微抬升并亮强调色边框。
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
        .scaleEffect(hovering && !disabled ? 1.02 : 1.0)
        .animation(.snappy(duration: 0.15), value: hovering)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .onHover { hovering = $0 }
    }
}

/// 3D 猜拳舞台：两只手带 X 轴透视蓄力俯仰，落定瞬间向前冲刺。
struct RPSStage: View {
    @Environment(AppModel.self) private var model
    let myMove: RPS?
    let aiMove: RPS?
    let rolling: Bool
    let resultText: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 0) {
                HandColumn(title: "你", move: myMove, rolling: rolling,
                           highlight: true, winner: resultText == "你赢了",
                           motion3D: model.motion3D, swingPhase: 0)
                Text("VS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 52)
                HandColumn(title: "电脑", move: aiMove, rolling: rolling,
                           highlight: false, winner: resultText == "你输了",
                           motion3D: model.motion3D, swingPhase: .pi)
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
    let winner: Bool
    let motion3D: Bool
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
                        .fill(winner
                              ? Color.green.opacity(0.14)
                              : (highlight ? Color.accentColor.opacity(0.13) : Color.primary.opacity(0.05)))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(winner ? Color.green.opacity(0.45) : Color.clear, lineWidth: 1.2)
                        }

                    if let move {
                        VStack(spacing: 1) {
                            Text(move.glyph)
                                .font(.system(size: 42))
                            Text(move.title)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .offset(y: swing * 8)
                        .rotationEffect(.degrees(swing * 6))
                        .rotation3DEffect(
                            .degrees(motion3D ? swing * 22 : 0),
                            axis: (x: 1, y: 0, z: 0),
                            perspective: 0.55
                        )
                    } else {
                        Text("?")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.quaternary)
                            .offset(y: swing * 5)
                    }
                }
                .frame(height: 110)
                .scaleEffect(push)
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: rolling) { _, r in
            guard !r else { return }
            let d = highlight ? 0.0 : 0.09
            push = 1.18
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55).delay(d)) { push = 1 }
        }
    }
}

// MARK: - 滚轮文字封装

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

struct RollingNumberUnit: View {
    let text: String
    var size: CGFloat = 132

    var body: some View {
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

// MARK: - 3D 随机颜色

/// 颜色舞台：色块悬停 3D 微倾，落定双层同色光环向外扩散。
struct ColorStage: View {
    @Environment(AppModel.self) private var model
    let color: Color
    let hex: String
    let rgbText: String
    let hsbText: String
    let rolling: Bool
    let pulse: Int

    @State private var ring: CGFloat = 0
    @State private var breathe: CGFloat = 1
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // 双层同色扩散光环
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(color.opacity(0.55 * (1 - ring)), lineWidth: 2)
                    .frame(height: 110)
                    .frame(maxWidth: 320)
                    .scaleEffect(x: 1 + ring * 0.12, y: 1 + ring * 0.32)
                    .opacity(ring > 0 && ring < 1 ? 1 : 0)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(color.opacity(0.32 * (1 - ring)), lineWidth: 1.5)
                    .frame(height: 110)
                    .frame(maxWidth: 320)
                    .scaleEffect(x: 1 + ring * 0.22, y: 1 + ring * 0.48)
                    .opacity(ring > 0.1 && ring < 1 ? 1 : 0)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color)
                    .frame(height: 110)
                    .frame(maxWidth: 320)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.24), .clear, Color.black.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.26), lineWidth: 0.6)
                    }
                    .scaleEffect(hovering && !rolling ? 1.025 : breathe)
                    .rotation3DEffect(
                        .degrees(model.motion3D && hovering && !rolling ? 6 : 0),
                        axis: (x: 1, y: -0.6, z: 0),
                        perspective: 0.6
                    )
                    .shadow(color: color.opacity(rolling ? 0.38 : 0.22),
                            radius: rolling ? 14 : 8, y: 4)
                    .animation(.snappy(duration: 0.20), value: hovering)
                    .onHover { hovering = $0 }
            }
            .frame(height: 122)

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
            withAnimation(.easeOut(duration: 0.60)) { ring = 1 }
        }
    }
}

// MARK: - 3D 随机分组

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
                ShufflingPile(index: i, label: sample(i), motion3D: model.motion3D)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ShufflingPile: View {
    let index: Int
    let label: String
    let motion3D: Bool

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

            SlotRoller(value: label, distance: 15, duration: 0.09) { v in
                Text(v)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 17)

            TimelineView(.animation(minimumInterval: 1.0 / 40)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                HStack(spacing: -11) {
                    ForEach(0..<3, id: \.self) { k in
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(Color.accentColor.opacity(0.68 - Double(k) * 0.12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.60), lineWidth: 0.8)
                            }
                            .frame(width: 22, height: 30)
                            .rotationEffect(.degrees(Double(k - 1) * 5))
                            .rotation3DEffect(
                                .degrees(motion3D ? 18 : 0),
                                axis: (x: 1, y: 0, z: 0),
                                perspective: 0.6
                            )
                            .offset(x: sin(t * 5.8 + Double(index) * 1.3 + Double(k) * 0.8) * 3.5,
                                    y: cos(t * 4.2 + Double(k)) * 1.5)
                    }
                }
                .frame(height: 34, alignment: .leading)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        }
    }
}

// MARK: - 随机顺序

struct SequenceStage: View {
    @Environment(AppModel.self) private var model
    var preview: Int = 3

    private var scale: CGFloat { model.effectiveStageScale }

    private func name(at i: Int) -> String {
        guard i < model.sequenceResult.count else { return "　" }
        let no = model.sequenceResult[i]
        return model.name(no: no) ?? "\(model.fmtNo(no)) 号"
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(model.sequenceRolling ? "正在打乱…" : "第 1 位")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)

            if model.sequenceRolling {
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
                                    .foregroundStyle(i == 0 ? model.resolvedStageAccent : Color.primary)
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
                    .foregroundStyle(model.resolvedStageAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .resultPop(model.celebration)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.16), value: model.sequenceRolling)
    }
}

// MARK: - 3D 是或否

/// 是或否：滚动时沿 Y/Z 轴做 3D 跷跷板摇摆，落定弹性归正。
struct YesNoStage: View {
    @Environment(AppModel.self) private var model
    let text: String
    let positive: Bool
    let rolling: Bool
    var size: CGFloat = 124

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 45, paused: !rolling)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let wobble = rolling
                ? sin(t * 8.4) * 7.5 + sin(t * 3.7) * 2
                : 0
            let yaw = rolling && model.motion3D ? sin(t * 6.2) * 24 : 0

            RollingNumber(text: text,
                          size: text.count > 1 ? size * 0.62 : size,
                          tint: positive ? Color.green : Color.red)
                .rotationEffect(.degrees(wobble))
                .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                .offset(x: rolling ? sin(t * 5.1) * 10 : 0)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: rolling)
    }
}

// MARK: - 点名扫描

struct SpotlightSweep: View {
    @Environment(AppModel.self) private var model
    let active: Bool
    @Environment(\.colorScheme) private var scheme

    private var lineOpacity: Double { scheme == .dark ? 0.48 : 0.24 }
    private var glowOpacity: Double { scheme == .dark ? 0.32 : 0.14 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 45, paused: !active)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let sweep = (sin(t * 2.6) + 1) / 2
            GeometryReader { geo in
                let w = geo.size.width
                let x = w * sweep
                ZStack(alignment: .leading) {
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [model.resolvedStageAccent.opacity(glowOpacity), .clear],
                                center: .center, startRadius: 0, endRadius: 48)
                        )
                        .frame(width: 156, height: geo.size.height * 0.92)
                        .offset(x: x - 78)

                    Rectangle()
                        .fill(model.resolvedStageAccent.opacity(lineOpacity))
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
