import SwiftUI
import AppKit

// MARK: - 随机分组（2.0）
//
// 音乐课的高频需求：分成 4 组做节奏合奏、6 人一组做小组创编。
// 分组结果直接列姓名（带不带学号可切），一键复制就能贴到班级群。

struct GroupingView: View {
    @Environment(AppModel.self) private var model
    @State private var copied = false

    private var caption: String {
        guard model.hasClasses else { return "先导入名单" }
        if model.groups.isEmpty {
            return "全班 \(model.classCount) 人 · 将分成 \(model.plannedGroupCount) 组"
        }
        return "\(model.groups.count) 组 · 各组人数 \(GroupSplit.sizeSummary(model.groups))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StageCard(minHeight: 190) {
                    VStack(spacing: 14) {
                        StageBadge(symbol: "person.3.sequence", value: model.groups.count)

                        if !model.hasClasses {
                            EmptyStage(text: "还没有班级名单", symbol: "square.and.arrow.down",
                                       height: 110)
                        } else if model.groups.isEmpty {
                            EmptyStage(text: "还没分过组", symbol: "person.3.sequence",
                                       height: 110)
                        } else if model.groupingRolling {
                            // 洗牌的过程本身就是信息：老师在等这几摞牌分完
                            GroupShuffleStage()
                        } else {
                            groupCards
                        }

                        StageCaption(text: caption)
                    }
                }
                .animation(.snappy(duration: 0.14), value: model.groups)

                PrimaryButton(title: "分组", symbol: "person.3.sequence",
                              disabled: !model.hasClasses || model.groupingRolling) {
                    model.drawGroups()
                }

                SectionLabel("分组设置", count: model.groups.isEmpty ? nil : "\(model.groups.count) 组") {
                    ClearButton(title: copied ? "已复制" : "复制分组",
                                symbol: copied ? "checkmark" : "doc.on.doc",
                                tint: copied ? .green : .accentColor,
                                disabled: model.groups.isEmpty) {
                        model.copyGroups()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    }
                }

                if model.hasClasses {
                    CardGroup {
                        Bar {
                            HStack(spacing: 12) {
                                Text("分组班级").font(.system(size: 13))
                                Spacer(minLength: 12)
                                Picker("", selection: Binding(
                                    get: { model.classID },
                                    set: { model.switchClass($0) }
                                )) {
                                    ForEach(model.activeClasses) { cls in
                                        Text("\(cls.shortTitle)（\(cls.count) 人）").tag(cls.id)
                                    }
                                }
                                .labelsHidden()
                                .frame(maxWidth: 220)
                            }
                        }

                        OptionField("方式") {
                            Picker("", selection: model.binding(\.groupMode)) {
                                ForEach(GroupMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }

                        OptionBar(model.groupMode == .byGroups ? "分成几组" : "每组几人",
                                  hint: model.groupMode == .byGroups
                                        ? "人数自动均分，最多差 1 人"
                                        : "组数自动算，最多差 1 人") {
                            if model.groupMode == .byGroups {
                                NumberField(value: model.binding(\.groupCount), suffix: "组",
                                            range: GroupSplit.groupRange)
                            } else {
                                NumberField(value: model.binding(\.groupSize), suffix: "人",
                                            range: GroupSplit.sizeRange)
                            }
                        }

                        OptionBar("显示学号", hint: "关掉只显示姓名") {
                            Toggle("", isOn: model.binding(\.groupShowNumbers))
                                .toggleStyle(.switch).labelsHidden()
                        }
                    }
                }

                Spacer(minLength: 2)
            }
            .padding(20)
        }
        .background(Color.clear)
    }

    /// 每组一张卡片，自适应列数（窄窗口自动变一列）。
    private var groupCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)],
                  alignment: .leading, spacing: 10) {
            ForEach(Array(model.groups.enumerated()), id: \.offset) { index, members in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("第 \(index + 1) 组")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        Spacer(minLength: 4)
                        Text("\(members.count) 人")
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Text(members.map { no -> String in
                        let name = model.name(no: no) ?? "?"
                        // 学号与姓名之间用不换行空格：换行时「20 2601-20」不能被拆成两行，
                        // 否则屏幕上会蹦出一个孤零零的数字，看着像数据坏了。
                        return model.groupShowNumbers
                            ? "\(model.fmtNo(no))\u{00A0}\(name)"
                            : name
                    }.joined(separator: "　"))
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 随机数字

struct RandomNumberView: View {
    @Environment(AppModel.self) private var model

    private var display: String { model.numResults.map(String.init).joined(separator: "  ") }

    /// 舞台下方的说明：把「还会不会重复」说清楚。
    /// 原来只写「1 – 70 之间抽 1 个」，老师根本不知道这个工具记不记得抽过谁。
    private var caption: String {
        let base = "\(model.numLo) – \(model.numHi) 之间抽 \(model.numCount) 个"
        guard model.numNoRepeat else { return base + " · 每次独立抽取，会重复" }
        if model.numPoolEmpty { return base + " · 这一轮已抽完，点「清空」重来" }
        return base + " · 还剩 \(model.numRemaining) 个没抽过"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StageCard(minHeight: 178) {
                    VStack(spacing: 10) {
                        StageBadge(symbol: "arrow.left.arrow.right", value: model.numResults)
                            .opacity(model.numResults.isEmpty ? 0 : 1)
                        if model.numResults.isEmpty {
                            EmptyStage(text: "待抽取", symbol: "arrow.left.arrow.right", height: 96)
                        } else {
                            RollingNumber(text: display,
                                          size: (model.numResults.count > 1 ? 64 : 112) * model.effectiveStageScale)
                                .resultPop(model.celebration)
                        }
                        StageCaption(text: caption)
                    }
                }
                .animation(.snappy(duration: 0.12), value: model.numResults)
                .celebrationOverlay(model.celebration, theme: model.celebrationTheme,
                     level: model.effectLevel)

                PrimaryButton(title: "抽取", symbol: "arrow.left.arrow.right",
                              disabled: model.numRolling || model.numPoolEmpty) { model.drawNumbers() }

                SectionLabel("抽取范围")

                CardGroup {
                    Bar {
                        HStack(alignment: .bottom, spacing: 18) {
                            CountField(label: "最小值", value: model.binding(\.numMin))
                            CountField(label: "最大值", value: model.binding(\.numMax))
                            Spacer(minLength: 8)
                            NumberField(label: "抽取个数", value: model.binding(\.numCount),
                                        suffix: "个", range: 1...20)
                        }
                    }

                    OptionBar("一次抽多个时不重复") {
                        Toggle("", isOn: model.binding(\.numUnique))
                            .toggleStyle(.switch).labelsHidden()
                    }

                    OptionBar("抽过的不再抽",
                              hint: "本轮已抽 \(model.numRangeSize - model.numPool.count) / \(model.numRangeSize) 个") {
                        HStack(spacing: 10) {
                            Button("清空") { model.resetNumbers() }
                                .buttonStyle(.borderless)
                                // borderless 不带 tint 时是灰字，和同页其它蓝色次要操作
                                // （「清空记录」「放回全部」）不是一个样子。
                                .tint(.accentColor)
                                .disabled(model.numDrawn.isEmpty)
                            Toggle("", isOn: model.binding(\.numNoRepeat))
                                .toggleStyle(.switch).labelsHidden()
                        }
                    }
                }

                if model.numNoRepeat {
                    Text("开启后它就像点名一样不会重复；关掉则每次都是独立随机（真的会连抽同一个数）。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                Spacer(minLength: 2)
            }
            .padding(20)
        }
        .background(Color.clear)
    }
}

// MARK: - 骰子

struct DiceView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StageCard(minHeight: 190) {
                    VStack(spacing: 16) {
                        // 骰子会滚（DiceStage）：每颗相位错开地乱晃，落桌时砸一下。
                        // 原来只用 symbolEffect(.bounce) 弹一下，像图标而不是骰子。
                        DiceStage(values: model.diceValues,
                                  faces: model.diceFaces,
                                  rolling: model.diceRolling)

                        StageCaption(text: model.diceValues.count > 1
                                     ? "合计 \(model.diceSum)　·　\(model.diceValues.map(String.init).joined(separator: " + "))"
                                     : "点数 \(model.diceValues.first ?? 1)")
                    }
                }

                PrimaryButton(title: "掷骰子", symbol: "die.face.6",
                              disabled: model.diceRolling) { model.rollDice() }

                SectionLabel("骰子设置")

                CardGroup {
                    OptionBar("骰子个数") {
                        NumberField(value: model.binding(\.diceCount), suffix: "颗", range: 1...8)
                    }

                    OptionField("每颗面数") {
                        Picker("", selection: model.binding(\.diceFaces)) {
                            Text("D4").tag(4)
                            Text("D6").tag(6)
                            Text("D8").tag(8)
                            Text("D10").tag(10)
                            Text("D12").tag(12)
                            Text("D20").tag(20)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                Text("面数为 6 时显示标准骰面，其他面数直接显示点数。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                Spacer(minLength: 2)
            }
            .padding(20)
        }
        .background(Color.clear)
    }
}

struct DieFace: View {
    let value: Int
    let faces: Int

    private var size: CGFloat { faces == 6 ? 64 : 70 }

    var body: some View {
        Group {
            if faces == 6 {
                Image(systemName: "die.face.\(min(max(value, 1), 6))")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
            } else {
                Text("\(value)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(.primary)
                    .frame(width: size, height: size)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1.5)
                    }
            }
        }
    }
}

// MARK: - 硬币

struct CoinView: View {
    @Environment(AppModel.self) private var model

    private var total: Int { model.coinHeads + model.coinTails }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StageCard(minHeight: 232) {
                    // 硬币自己会翻（见 CoinStage）：抛起来、在空中转、落地砸一下再晃两下。
                    // 原来只是给整个圆盘套了个 rotation3DEffect，转起来文字还是镜像的。
                    CoinStage()
                }

                PrimaryButton(title: "抛硬币", symbol: "arrow.triangle.2.circlepath",
                              disabled: model.coinRolling) { model.flipCoin() }

                SectionLabel("统计") {
                    ClearButton(disabled: total == 0) { model.resetCoin() }
                }

                Bar {
                    HStack(spacing: 10) {
                        StatTile(value: "\(model.coinHeads)", label: "正面", symbol: "circle")
                        Divider().frame(height: 24)
                        StatTile(value: "\(model.coinTails)", label: "反面", symbol: "circle.dashed")
                        Divider().frame(height: 24)
                        StatTile(value: "\(total)", label: "总次数", tint: .accentColor)
                        Spacer(minLength: 0)
                    }
                }

                Spacer(minLength: 2)
            }
            .padding(20)
        }
        .background(Color.clear)
    }
}

// MARK: - 抽卡

struct CardView: View {
    @Environment(AppModel.self) private var model

    private var summary: String {
        guard !model.cards.isEmpty else { return "" }
        return model.cards.map { c in
            c.suit.map { "\($0.label)\(c.rank)" } ?? c.rank
        }.joined(separator: "、")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StageCard(minHeight: 200) {
                    VStack(spacing: 12) {
                        // 这里原来有个 ♠ 徽标，但牌本身就是画面主体，
                        // 一个孤零零的黑桃飘在牌上方只会显得多余 —— 去掉。

                        if model.cards.isEmpty && !model.cardRolling {
                            EmptyStage(text: "待抽牌", symbol: "suit.spade", height: 118)
                        } else {
                            // 洗牌 → 逐张翻开（CardStage）。牌背到牌面那一下必须真的"翻"，
                            // 只换图的话，看着像换了张图片而不是抽了张牌。
                            CardStage(cards: model.cards,
                                      count: model.cardDrawCount,
                                      rolling: model.cardRolling,
                                      round: model.celebration,
                                      width: model.cards.count > 4 ? 64 : 90)
                        }

                        StageCaption(text: summary.isEmpty ? "一副 52 张，可加大小王" : summary)
                    }
                }
                .animation(.snappy(duration: 0.14), value: model.cards)

                PrimaryButton(title: "抽一张", symbol: "suit.spade.fill",
                              disabled: model.cardRolling) { model.drawCards() }

                SectionLabel("牌堆设置")

                CardGroup {
                    OptionBar("每次抽几张") {
                        NumberField(value: model.binding(\.cardDrawCount), suffix: "张",
                                    range: 1...10)
                    }

                    OptionBar("包含大小王", hint: "共 54 张") {
                        Toggle("", isOn: model.binding(\.includeJokers))
                            .toggleStyle(.switch).labelsHidden()
                    }
                }

                Spacer(minLength: 2)
            }
            .padding(20)
        }
        .background(Color.clear)
    }
}

// MARK: - 随机颜色

struct ColorView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StageCard(minHeight: 210) {
                    // 色块抽的时候在"呼吸"，落定时向外扩一圈同色光环（ColorStage）。
                    ColorStage(color: model.colorSwatch,
                               hex: model.colorHex,
                               rgbText: model.colorRGBText,
                               hsbText: model.colorHSBText,
                               rolling: model.colorRolling,
                               pulse: model.celebration)
                }

                PrimaryButton(title: "换一个颜色", symbol: "paintpalette.fill",
                              disabled: model.colorRolling) { model.drawColor() }

                SectionLabel("取色范围") {
                    ClearButton(title: model.copied ? "已复制" : "复制色值",
                                symbol: model.copied ? "checkmark" : "doc.on.doc",
                                tint: model.copied ? .green : .accentColor) {
                        model.copyHex()
                    }
                }

                Bar {
                    Picker("", selection: model.binding(\.paletteMode)) {
                        ForEach(ColorPaletteMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Spacer(minLength: 2)
            }
            .padding(20)
        }
        .background(Color.clear)
    }
}

// MARK: - 随机字母

struct LetterView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StageCard(minHeight: 184) {
                    VStack(spacing: 10) {
                        StageBadge(symbol: "a.square", value: model.letterResult)
                            .opacity(model.letterResult.isEmpty ? 0 : 1)
                        if model.letterResult.isEmpty {
                            EmptyStage(text: "待抽取", symbol: "a.square", height: 100)
                        } else {
                            RollingNumber(text: model.letterDisplay(model.letterResult),
                                          size: 108 * model.effectiveStageScale)
                        }
                        StageCaption(text: "范围 \(model.letterScope.title)")
                    }
                }
                .animation(.snappy(duration: 0.12), value: model.letterResult)
                .celebrationOverlay(model.celebration, theme: model.celebrationTheme,
                     level: model.effectLevel)

                PrimaryButton(title: "抽取", symbol: "a.square",
                              disabled: model.letterRolling) { model.drawLetter() }

                SectionLabel("设置")

                CardGroup {
                    OptionField("字母范围") {
                        Picker("", selection: model.binding(\.letterScope)) {
                            ForEach(LetterScope.allCases) { s in
                                Text(s.title).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    OptionBar("大写显示") {
                        Toggle("", isOn: model.binding(\.letterUppercase))
                            .toggleStyle(.switch).labelsHidden()
                    }
                }

                Spacer(minLength: 2)
            }
            .padding(20)
        }
        .background(Color.clear)
    }
}

// MARK: - 剪刀石头布

struct RPSView: View {
    @Environment(AppModel.self) private var model

    private var rounds: Int { model.rpsWins + model.rpsLosses + model.rpsDraws }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StageCard(minHeight: 208) {
                    // 猜拳就是两只手：预备时上下晃，落定时推出去（RPSStage）。
                    RPSStage(myMove: model.myMove,
                             aiMove: model.aiMove,
                             rolling: model.rpsRolling,
                             resultText: model.rpsResultText)
                }

                HStack(spacing: 12) {
                    ForEach(RPS.allCases) { move in
                        MoveButton(move: move, disabled: model.rpsRolling) {
                            model.play(move)
                        }
                    }
                }

                SectionLabel("战绩", count: rounds > 0 ? "\(rounds) 局" : nil) {
                    ClearButton(disabled: rounds == 0) { model.resetRPS() }
                }

                Bar {
                    HStack(spacing: 10) {
                        StatTile(value: "\(model.rpsWins)", label: "胜",
                                 tint: .green, symbol: "hand.thumbsup")
                        Divider().frame(height: 24)
                        StatTile(value: "\(model.rpsLosses)", label: "负",
                                 tint: .red, symbol: "hand.thumbsdown")
                        Divider().frame(height: 24)

                        StatTile(value: "\(model.rpsDraws)", label: "平",
                                 symbol: "equal")
                        Spacer(minLength: 0)
                    }
                }

                Spacer(minLength: 2)
            }
            .padding(20)
        }
        .background(Color.clear)
    }
}

// MARK: - 是或否

struct YesNoView: View {
    @Environment(AppModel.self) private var model

    private var total: Int { model.yesCount + model.noCount }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StageCard(minHeight: 206) {
                    VStack(spacing: 12) {
                        StageBadge(symbol: "questionmark.circle",
                                   value: model.yesNoResult ?? false)
                            .opacity(model.yesNoResult == nil ? 0 : 1)

                        if let result = model.yesNoResult {
                            YesNoStage(text: result ? "是" : "否",
                                       positive: result,
                                       rolling: model.yesNoRolling,
                                       size: 124 * model.effectiveStageScale)
                        } else {
                            EmptyStage(text: "想个问题，再抽", symbol: "questionmark",
                                       height: 110)
                        }

                        StageCaption(text: model.yesNoResult == nil
                                     ? "让随机帮你做决定"
                                     : (model.yesNoResult! ? "答案是：是" : "答案是：否"))
                    }
                }
                .animation(.snappy(duration: 0.12), value: model.yesNoResult ?? false)
                .celebrationOverlay(model.celebration, theme: model.celebrationTheme,
                     level: model.effectLevel)

                PrimaryButton(title: "抽取", symbol: "questionmark.circle",
                              disabled: model.yesNoRolling) { model.drawYesNo() }

                SectionLabel("统计", count: total > 0 ? "共 \(total) 次" : nil) {
                    ClearButton(disabled: total == 0) { model.resetYesNo() }
                }

                Bar {
                    HStack(spacing: 10) {
                        StatTile(value: "\(model.yesCount)", label: "是",
                                 tint: .green, symbol: "checkmark")
                        Divider().frame(height: 24)
                        StatTile(value: "\(model.noCount)", label: "否",
                                 tint: .red, symbol: "xmark")
                        Divider().frame(height: 24)

                        StatTile(value: "\(total)", label: "总次数", tint: .accentColor)
                        Spacer(minLength: 0)
                    }
                }

                Spacer(minLength: 2)
            }
            .padding(20)
        }
        .background(Color.clear)
    }
}


// MARK: - 随机顺序（3.0）
//
// 点名每次只给一个人；这个要的是**全班的一个排列**。
// 课堂里的真实用途：排发言顺序、排队、分站轮转 —— 只抽一个人解决不了。

struct SequenceView: View {
    @Environment(AppModel.self) private var model
    @State private var copied = false

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StageCard(minHeight: 140) {
                    VStack(spacing: 10) {
                        if !model.hasClasses {
                            EmptyStage(text: "还没有班级名单", symbol: "square.and.arrow.down",
                                       height: 96)
                        } else if model.sequenceResult.isEmpty {
                            EmptyStage(text: "还没有打乱过", symbol: "list.number",
                                       height: 96)
                        } else {
                            SequenceStage()
                            StageCaption(text: model.sequenceRolling
                                         ? "全班 \(model.sequenceResult.count) 人 · 正在洗牌"
                                         : "全班 \(model.sequenceResult.count) 人 · 顺序已打乱")
                        }
                    }
                }
                .celebrationOverlay(model.celebration, theme: model.celebrationTheme,
                     level: model.effectLevel)

                PrimaryButton(title: "打乱顺序", symbol: "shuffle",
                              disabled: !model.hasClasses || model.sequenceRolling) {
                    model.drawSequence()
                }

                // 顺序是按「当前班」排的，所以这里必须能换班 ——
                // 和分组页一样在原地换，不走侧边栏（那会直接跳走）。
                if model.hasClasses {
                    SectionLabel("顺序设置", count: "\(model.classCount) 人")

                    CardGroup {
                        Bar {
                            HStack(spacing: 12) {
                                Text("顺序班级").font(.system(size: 13))
                                Spacer(minLength: 12)
                                Picker("", selection: Binding(
                                    get: { model.classID },
                                    set: { model.switchClass($0) }
                                )) {
                                    ForEach(model.activeClasses) { cls in
                                        Text("\(cls.shortTitle)（\(cls.count) 人）").tag(cls.id)
                                    }
                                }
                                .labelsHidden()
                                .frame(maxWidth: 220)
                            }
                        }
                    }
                }

                if !model.sequenceResult.isEmpty {
                    SectionLabel("完整顺序", count: "\(model.sequenceResult.count) 人") {
                        ClearButton(title: copied ? "已复制" : "复制顺序",
                                    symbol: copied ? "checkmark" : "doc.on.doc",
                                    tint: copied ? .green : .accentColor) {
                            copyOrder()
                        }
                    }

                    StageCard {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                            ForEach(Array(model.sequenceResult.enumerated()), id: \.offset) { i, no in
                                HStack(spacing: 7) {
                                    Text("\(i + 1)")
                                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20, alignment: .trailing)
                                    Text(model.name(no: no) ?? "\(no) 号")
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 3)
                                .padding(.horizontal, 7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.05),
                                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func copyOrder() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(model.sequencePlainText, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }
}
