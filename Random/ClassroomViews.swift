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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StageCard(minHeight: 190) {
                    VStack(spacing: 10) {
                        StageBadge(symbol: "graduationcap", value: model.pickResults)

                        if model.pickResults.isEmpty {
                            EmptyStage(text: "还没有点过名", symbol: "hand.wave",
                                       height: 104)
                        } else if multi {
                            // 点名滚动用滚轮，不用淡入淡出 —— 名字往上走，
                            // 才像在花名册上一行一行往下点。
                            RollingNumber(text: display, size: 78 * model.effectiveStageScale)
                                .resultPop(model.celebration)
                        } else {
                            RollingNumberUnit(text: display,
                                              size: 122 * model.effectiveStageScale)
                                .resultPop(model.celebration)
                        }

                        if !model.pickedNames.isEmpty {
                            RollingNames(text: model.pickedNames.joined(separator: "、"),
                                         size: multi ? 20 : 22)
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

                // 三行开关属于同一件事，装在一张卡片里（组内用细线分隔）。
                CardGroup {
                    OptionBar("每次点几名", hint: "可同时抽多人") {
                        NumberField(value: model.binding(\.pickCount), suffix: "人",
                                    range: 1...10)
                    }

                    OptionBar("不重复", hint: "点过的本轮不再点") {
                        Toggle("", isOn: model.binding(\.noRepeat))
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    OptionBar("补零显示", hint: "7 号显示为 07") {
                        Toggle("", isOn: model.binding(\.padZero))
                            .toggleStyle(.switch)
                            .labelsHidden()
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
                        EmptyRecords(text: "还没有记录。抽过的号码会留在这一栏，点一下可放回。")
                    } else {
                        FlowGrid(items: model.drawn.sorted(), spacing: 7, minimum: 112) { n in
                            RecordChip(text: model.fmtNo(n), sub: model.name(no: n)) {
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
                            Text("历史从 2.0 起记录。升级前点过的名字没有时间戳，不补进来 —— 这里只统计真发生过的事。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if model.classCount == 0 {
                            Text("还没有名单").font(.caption).foregroundStyle(.tertiary)
                        } else {
                            FlowGrid(items: model.leastPicked(of: model.classID, limit: 6),
                                     spacing: 7, minimum: 112) { stat in
                                PickStatChip(no: model.fmtNo(stat.no),
                                             name: stat.name,
                                             count: stat.count)
                            }
                        }
                    }
                }

                Spacer(minLength: 2)
            }
            .padding(20)
        }
        .background(Color.clear)
    }
}

/// 「被点次数」小胶囊：0 次用橙色标出来 —— 那才是老师真正要留意的人。
private struct PickStatChip: View {
    let no: String
    let name: String
    let count: Int

    // 和「已抽记录」同一套网格语言：无底色，学号弱、姓名强，
    // 次数右对齐成一列。橙色只用来把"没点过"这三个字挑出来 ——
    // 之前整块橙色底，一个卡片里六张橙纸，比结果本身还抢。
    var body: some View {
        HStack(spacing: 6) {
            Text(no)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(name)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(count == 0 ? "没点过" : "\(count) 次")
                .font(.system(size: 11))
                .foregroundStyle(count == 0 ? Color.orange : Color.secondary)
        }
        .font(.system(size: 13))
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
