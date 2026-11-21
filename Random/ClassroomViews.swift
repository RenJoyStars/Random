import SwiftUI

// MARK: - 班级（抽学号 + 点名合一，每班独立记忆）
//
// 六个班各是侧边栏里独立的一栏，记录分别持久化在 UserDefaults，
// 关掉应用再打开仍在，只有主动「清空记录」才会抹掉。

struct ClassroomView: View {
    @Environment(AppModel.self) private var model

    private var display: String {
        model.pickResults.map { model.fmtNo($0) }.joined(separator: "  ")
    }

    private var multi: Bool { model.pickResults.count > 1 }

    /// 舞台未开抽时的状态提示：
    /// 区分「真未点过（还未开始点名）」与「此前已点过（点击下方按钮开始点名）」，以及「本轮已全员点毕」
    private var emptyStageContent: (title: String, subtitle: String, symbol: String) {
        let drawn = model.drawnCount(of: model.classID)
        let total = model.classCount
        if drawn == 0 {
            return (
                title: "还未开始点名",
                subtitle: "按下方「点名」或快捷键 ⌘↩ 开始",
                symbol: "hand.wave"
            )
        } else if model.noRepeat && drawn >= total && total > 0 {
            return (
                title: "本轮全员已点毕",
                subtitle: "可点击下方清空或关闭不重复重新开始",
                symbol: "checkmark.circle.fill"
            )
        } else {
            return (
                title: "点击下方按钮开始点名",
                subtitle: "本轮已点 \(drawn) 人 · 剩余 \(model.pickRemaining) 人待抽",
                symbol: "play.circle"
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: LayoutMetrics.pageSpacing) {
                StageCard(minHeight: 190) {
                    VStack(spacing: 10) {
                        StageBadge(symbol: "graduationcap", value: model.pickResults)

                        if model.pickResults.isEmpty {
                            let empty = emptyStageContent
                            EmptyStage(text: empty.title,
                                       subtitle: empty.subtitle,
                                       symbol: empty.symbol,
                                       height: 104)
                        } else if model.pickResults.count >= 5 {
                            // 5~10 人群抽：自动转为多卡片大字网格，避免长文本被系统截断成省略号
                            MultiPickGrid(numbers: model.pickResults,
                                          showNumber: model.showStudentNumber,
                                          scale: model.effectiveStageScale)
                                .resultPop(model.celebration)
                        } else if !model.showStudentNumber && !model.pickedNames.isEmpty {
                            // 默认仅展示姓名（大字居中），使用 RollingNumber，纯姓名后绝不带奇怪的「号」字
                            if model.pickResults.count >= 3 {
                                RollingNumber(text: model.pickedNames.joined(separator: "  "),
                                              size: 44 * model.effectiveStageScale)
                                    .resultPop(model.celebration)
                            } else if multi {
                                RollingNumber(text: model.pickedNames.joined(separator: "  "),
                                              size: 64 * model.effectiveStageScale)
                                    .resultPop(model.celebration)
                            } else {
                                RollingNumber(text: model.pickedNames.first ?? display,
                                              size: 96 * model.effectiveStageScale)
                                    .resultPop(model.celebration)
                            }
                        } else if multi {
                            RollingNumber(text: display,
                                          size: (model.pickResults.count >= 3 ? 56 : 78) * model.effectiveStageScale)
                                .resultPop(model.celebration)
                        } else {
                            RollingNumberUnit(text: display,
                                              size: 122 * model.effectiveStageScale)
                                .resultPop(model.celebration)
                        }

                        if model.showStudentNumber && !model.pickedNames.isEmpty && model.pickResults.count < 5 {
                            RollingNames(text: model.pickedNames.joined(separator: "、"),
                                         size: multi ? (model.pickResults.count >= 3 ? 18 : 20) : 22)
                        }

                        StageCaption(text: model.pickMessage)
                    }
                }
                .animation(.snappy(duration: 0.12), value: model.pickResults)
                // 点名的专属识别度：一条光带在花名册上左右扫，落定就收掉。
                .overlay {
                    SpotlightSweep(active: model.pickRolling)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .celebrationOverlay(model.celebration, theme: model.celebrationTheme,
                     level: model.effectLevel)

                PrimaryButton(title: "点名", symbol: "megaphone.fill",
                              disabled: model.pickRolling) {
                    model.drawPick()
                }

                SectionLabel("设置")

                // 设置卡片（组内用细线分隔）。
                CardGroup {
                    OptionBar("每次点几名", hint: "可同时抽多人") {
                        NumberField(value: model.binding(\.pickCount), suffix: "人",
                                    range: 1...10)
                    }

                    OptionBar("公平点名", hint: "被点次数较少的同学优先被抽到") {
                        Toggle("", isOn: model.binding(\.fairPick))
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    OptionBar("不重复", hint: "点过的本轮不再点") {
                        Toggle("", isOn: model.binding(\.noRepeat))
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    OptionBar("显示学号", hint: "关掉后只突出展示姓名，避免插班生断号") {
                        Toggle("", isOn: model.binding(\.showStudentNumber))
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    if model.showStudentNumber {
                        OptionBar("补零显示", hint: "7 号显示为 07") {
                            Toggle("", isOn: model.binding(\.padZero))
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }
                }

                Bar {
                    HStack(spacing: 10) {
                        StatTile(value: "\(Set(model.drawn).count)",
                                 label: "已抽",
                                 symbol: "checkmark")

                        // 两块统计紧挨着会被读成一个整体（"046"），
                        // 一道细竖线把「本班进度」和「本轮剩余」分开。
                        Divider().frame(height: 24)

                        StatTile(value: "\(model.pickRemaining)",
                                 label: "本轮剩余",
                                 tint: model.pickRemaining == 0 ? .red : .accentColor,
                                 symbol: model.pickRemaining == 0 ? "exclamationmark" : "arrow.forward")
                        Spacer(minLength: 0)
                        ClearButton(title: "放回全部", symbol: "arrow.uturn.backward",
                                    disabled: model.drawn.isEmpty) {
                            withAnimation(.snappy(duration: 0.2)) { model.resetPick() }
                        }
                    }
                }

                SectionLabel("已抽记录", count: "\(model.drawn.count) 个") {
                    ClearButton(title: "清空记录",
                                disabled: model.drawn.isEmpty) {
                        withAnimation(.snappy(duration: 0.2)) { model.resetPick() }
                    }
                }

                Bar {
                    if model.drawn.isEmpty {
                        EmptyRecords(text: "还没有记录。抽过的同学会留在这一栏，点一下可放回。")
                    } else {
                        FlowGrid(items: model.drawn.sorted(), spacing: 7, minimum: 112) { n in
                            RecordChip(
                                text: model.showStudentNumber ? model.fmtNo(n) : (model.name(no: n) ?? model.fmtNo(n)),
                                sub: model.showStudentNumber ? model.name(no: n) : nil
                            ) {
                                withAnimation(.snappy(duration: 0.2)) { model.release(n) }
                            }
                        }
                    }
                }

                // MARK: 点名统计（2.0）
                //
                // 「是不是总点那几个人」这个问题，靠一学期的历史才答得出来。
                // 只统计点名，分组不算 —— 分组是随机分，不代表「被点到」。
                SectionLabel("点名统计",
                             count: model.pickEventCount(of: model.classID) > 0
                                    ? "共 \(model.pickEventCount(of: model.classID)) 次"
                                    : nil)

                Bar {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("被点得最少（下一轮优先关照）")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        if model.history.isEmpty {
                            Text("根据本学期点名历史自动统计，点名后此处将动态列出被点最少的同学，清空历史可重置。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if model.classCount == 0 {
                            Text("还没有名单").font(.caption).foregroundStyle(.tertiary)
                        } else {
                            FlowGrid(items: model.leastPicked(of: model.classID, limit: 6),
                                     spacing: 7, minimum: 112) { stat in
                                PickStatChip(no: model.showStudentNumber ? model.fmtNo(stat.no) : "",
                                             name: stat.name,
                                             count: stat.count)
                            }
                        }
                    }
                }

                Spacer(minLength: 2)
            }
            .macPagePadding()
        }
        .background(Color.clear)
    }
}

/// 「被点次数」小胶囊：0 次用橙色标出来 —— 那才是老师真正要留意的人。
private struct PickStatChip: View {
    let no: String
    let name: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            if !no.isEmpty {
                Text(no)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Text(name)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            if count == 0 {
                Text("没点过")
                    .font(.system(size: Type.caption, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            } else {
                Text("\(count) 次")
                    .font(.system(size: Type.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 13))
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 5~10 人群抽自适应大字网格：保证每位同学的姓名与学号完整醒目，绝不被单行截断
private struct MultiPickGrid: View {
    @Environment(AppModel.self) private var model
    let numbers: [Int]
    let showNumber: Bool
    let scale: Double

    private let columns = [GridItem(.adaptive(minimum: 118), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(numbers, id: \.self) { no in
                VStack(spacing: 3) {
                    if showNumber {
                        Text(model.fmtNo(no))
                            .font(.system(size: 20 * scale, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(model.name(no: no) ?? model.fmtNo(no))
                        .font(.system(size: (showNumber ? 17 : 22) * scale, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}
