import SwiftUI
import UniformTypeIdentifiers

// MARK: - 设置（⌘,）
//
// 遵循 macOS 27 Golden Gate 视觉语言：
// 采用原生卡片群（CardGroup）、舒适的行高与呼吸间距、同心连续圆角，
// 淘汰传统平铺 Form，呈现如系统设置般专业优雅的控制面板。

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("appearance") private var appearance: String = "system"
    @State private var editingClass: ClassRoster.SchoolClass?
    @State private var draft: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: LayoutMetrics.pageSpacing) {
                // MARK: 外观
                SectionLabel("外观")
                CardGroup {
                    OptionBar("主题", hint: "界面深浅色模式") {
                        Picker("主题", selection: $appearance) {
                            Text("跟随系统").tag("system")
                            Text("浅色").tag("light")
                            Text("深色").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 220)
                    }

                    OptionBar("舞台字号", hint: "投影大屏时只放大结果本身，不挤压操作区") {
                        HStack(spacing: 10) {
                            Slider(value: model.binding(\.stageScale), in: 0.8...1.6)
                                .frame(width: 140)
                            Text("\(Int((model.effectiveStageScale * 100).rounded()))%")
                                .font(.system(size: Type.caption).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 42, alignment: .trailing)
                            Button("默认") { model.stageScale = 1.0 }
                                .controlSize(.small)
                                .disabled(abs(model.stageScale - 1.0) < 0.001)
                        }
                    }
                }

                // MARK: 班级点名
                SectionLabel("班级点名")
                CardGroup {
                    OptionBar("不重复（点过的本轮不再点）", hint: "抽满全班前不出现重复名单") {
                        Toggle("", isOn: model.binding(\.noRepeat))
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    OptionBar("公平点名", hint: "被点次数较少的同学优先被抽到") {
                        Toggle("", isOn: model.binding(\.fairPick))
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    OptionBar("显示学号", hint: "关掉后只突出展示姓名，避免插班生断号困扰") {
                        Toggle("", isOn: model.binding(\.showStudentNumber))
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    if model.showStudentNumber {
                        OptionBar("补零显示（7 号显示为 07）", hint: "两位数等宽对齐") {
                            Toggle("", isOn: model.binding(\.padZero))
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }

                    OptionBar("每次点几名", hint: "支持单人抽答或 2~10 人群抽") {
                        NumberField(value: model.binding(\.pickCount), suffix: "人", range: 1...10)
                    }

                    OptionBar("抽取节奏", hint: "各随机工具的转盘滚动时长基线") {
                        HStack(spacing: 10) {
                            Slider(value: model.binding(\.pickSpeed), in: 0.5...1.8)
                                .frame(width: 140)
                            Text(String(format: "%.1f 秒", 0.95 * model.effectivePickSpeed))
                                .font(.system(size: Type.caption).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 48, alignment: .trailing)
                            Button("标准") { model.pickSpeed = 1.0 }
                                .controlSize(.small)
                                .disabled(abs(model.pickSpeed - 1.0) < 0.01)
                        }
                    }
                }

                // MARK: 音效
                SectionLabel("音效")
                CardGroup {
                    OptionBar("抽取音效", hint: "每个工具自带真实拟物过程音（骰子/硬币/洗牌等）") {
                        Toggle("", isOn: model.binding(\.soundOn))
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    OptionBar("音量") {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: Type.caption))
                                .foregroundStyle(.secondary)
                            Slider(value: model.binding(\.soundVolume), in: 0...1)
                                .frame(width: 140)
                            Text("\(Int((model.soundVolume * 100).rounded()))%")
                                .font(.system(size: Type.caption).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 38, alignment: .trailing)
                        }
                        .disabled(!model.soundOn)
                    }

                    OptionBar("落定音风格", hint: "钟声 / 琶音 / 木琴 / 电子") {
                        Picker("落定音风格", selection: model.binding(\.soundStyle)) {
                            Text("每次随机（\(SoundTheme.allCases.count) 种）").tag(SoundTheme.randomKey)
                            ForEach(SoundTheme.Family.allCases) { family in
                                Section(family.title) {
                                    ForEach(family.themes) { theme in
                                        Text(theme.title).tag(theme.rawValue)
                                    }
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: 160)
                        .disabled(!model.soundOn)
                        .onChange(of: model.soundStyle) { _, _ in
                            if model.soundOn { Sound.shared.victory() }
                        }
                    }

                    OptionBar("试听", hint: currentSoundName) {
                        Button("鼓点 + 落定音") { Sound.shared.preview() }
                            .controlSize(.small)
                            .disabled(!model.soundOn)
                    }
                }

                // MARK: 落定特效
                SectionLabel("落定特效")
                CardGroup {
                    OptionBar("落定特效", hint: "抽取揭晓时的庆祝粒子氛围") {
                        Picker("风格", selection: model.binding(\.celebrationStyle)) {
                            Text("每次随机（\(CelebrationTheme.allCases.count) 种）").tag(CelebrationTheme.randomKey)
                            ForEach(CelebrationTheme.Family.allCases) { family in
                                Section(family.title) {
                                    ForEach(family.themes) { theme in
                                        Text(theme.title).tag(theme.rawValue)
                                    }
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: 160)
                    }

                    OptionBar("当前主题", hint: "当前轮次展示效果") {
                        HStack(spacing: 6) {
                            Image(systemName: model.celebrationTheme.symbol)
                                .foregroundStyle(Color.accentColor)
                            Text(model.celebrationTheme.title)
                                .font(.system(size: Type.body))
                                .foregroundStyle(.secondary)
                        }
                    }

                    OptionBar("强度", hint: "老款 Mac 或大屏投影建议选精简") {
                        Picker("强度", selection: model.binding(\.effectLevel)) {
                            ForEach(EffectLevel.allCases) { level in
                                Text(level.title).tag(level)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: 160)
                    }
                }

                // MARK: 语音朗读
                SectionLabel("朗读")
                CardGroup {
                    OptionBar("点名后读出姓名", hint: "抽中后调用系统 TTS 语音直接播报") {
                        Toggle("", isOn: Binding(
                            get: { Speech.shared.enabled },
                            set: { Speech.shared.enabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    OptionBar("跟随系统朗读设置", hint: "与 VoiceOver 同款语音和语速") {
                        Toggle("", isOn: Binding(
                            get: { Speech.shared.followsSystemVoice },
                            set: { Speech.shared.followsSystemVoice = $0 }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    OptionBar("语音角色", hint: "系统已下载的中文语音包") {
                        Picker("语音", selection: Binding(
                            get: { Speech.shared.voiceIdentifier ?? "" },
                            set: { Speech.shared.voiceIdentifier = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("自动（挑质量最高的）").tag("")
                            ForEach(Speech.shared.voices, id: \.identifier) { v in
                                Text("\(Speech.displayName(v)) · \(v.language) · \(Speech.qualityLabel(v))").tag(v.identifier)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: 200)
                        .disabled(Speech.shared.followsSystemVoice)
                    }

                    OptionBar("当前使用") {
                        HStack(spacing: 10) {
                            Text(Speech.shared.currentVoiceDescription)
                                .font(.system(size: Type.caption))
                                .foregroundStyle(.secondary)
                            Button("重新扫描") { Speech.shared.rescanVoices() }
                                .controlSize(.small)
                                .help("刚在系统设置里下载完语音的话，点这里立刻生效")
                        }
                    }

                    if !Speech.hasHighQualityVoice {
                        Bar {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.system(size: 13))
                                Text("当前为「紧凑」档语音（机械感明显）。想要更自然，可在「系统设置 → 辅助功能 → 朗读内容」中下载增强语音，点「重新扫描」即可启用。注：Siri 的声音被系统锁给 Apple 自家应用。")
                                    .font(.system(size: Type.caption))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    OptionBar("朗读语速", hint: "当前 \(String(format: "%.2f", Speech.shared.rate))") {
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { Speech.shared.rate },
                                set: { Speech.shared.rate = $0 }
                            ), in: 0.3...0.6)
                            .frame(width: 140)
                            .disabled(Speech.shared.followsSystemVoice)

                            Button("试听") { Speech.shared.speak("张三") }
                                .controlSize(.small)
                                .disabled(!Speech.shared.enabled)
                        }
                    }
                }

                // MARK: 名单管理
                SectionLabel("名单来源")
                CardGroup {
                    if model.hasClasses {
                        OptionBar("当前名单", hint: "\(model.activeClasses.count) 个班级 · 共 \(model.activeClasses.reduce(0) { $0 + $1.count }) 人") {
                            HStack(spacing: 8) {
                                Text(model.importedRosterName ?? "已导入名单")
                                    .font(.system(size: Type.body))
                                    .foregroundStyle(.secondary)
                                Button("重新导入…") { importRosterViaPanel() }
                                    .controlSize(.small)
                                Button("移除", role: .destructive) {
                                    withAnimation(.snappy(duration: 0.2)) { model.clearRoster() }
                                }
                                .controlSize(.small)
                            }
                        }

                        ForEach(model.activeClasses) { cls in
                            OptionBar(cls.title, hint: "共 \(model.names(of: cls.id).count) 人 · 已抽 \(model.drawnCount(of: cls.id)) 人") {
                                HStack(spacing: 8) {
                                    if model.rosterOverrides[cls.id] != nil {
                                        Text("已自定义")
                                            .font(.system(size: Type.caption))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    Button("查看/微调") {
                                        draft = model.names(of: cls.id).joined(separator: "\n")
                                        editingClass = cls
                                    }
                                    .controlSize(.small)
                                }
                            }
                        }
                    } else {
                        OptionBar("暂未导入名单", hint: "支持 .randomroster 与 .json 格式") {
                            Button("导入名单文件…") { importRosterViaPanel() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                    }
                }

                // MARK: 数据重置
                SectionLabel("数据管理")
                CardGroup {
                    OptionBar("重置点名进度", hint: "清空所有班级当前的已抽记录") {
                        Button("清空全部班级点名") {
                            withAnimation(.snappy(duration: 0.2)) {
                                model.drawnByClass = [:]
                                model.pickResults = []
                                model.lastDrawn = []
                                model.persist()
                            }
                        }
                        .controlSize(.small)
                        .disabled(model.drawnByClass.isEmpty)
                    }

                    OptionBar("历史总账", hint: "已记录 \(model.history.count) 条历史数据") {
                        Button("清空历史记录（含点名统计）", role: .destructive) {
                            confirmClearHistory()
                        }
                        .controlSize(.small)
                        .disabled(model.history.isEmpty)
                    }

                    if !model.rosterOverrides.isEmpty {
                        OptionBar("还原名单", hint: "放弃本机手动微调的姓名") {
                            Button("清除名单的手动微调", role: .destructive) {
                                model.rosterOverrides = [:]
                                model.persist()
                            }
                            .controlSize(.small)
                        }
                    }
                }

                // MARK: 关于
                SectionLabel("关于")
                CardGroup {
                    OptionBar("Random 课堂点名器") {
                        Text(appVersion)
                            .font(.system(size: Type.caption))
                            .foregroundStyle(.secondary)
                    }
                    OptionBar("版权所有") {
                        Text(copyright)
                            .font(.system(size: Type.caption))
                            .foregroundStyle(.secondary)
                    }
                    OptionBar("数据存储") {
                        Text("全本地离线存储 · 隐私安全")
                            .font(.system(size: Type.caption))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)
            }
            .macPagePadding()
            .frame(maxWidth: 640)
        }
        .frame(minWidth: 540, minHeight: 560)
        .sheet(item: $editingClass) { cls in
            RosterSheet(cls: cls, draft: $draft) {
                let names = draft.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                if names.isEmpty {
                    model.rosterOverrides.removeValue(forKey: cls.id)
                } else {
                    model.rosterOverrides[cls.id] = names
                }
                model.persist()
                editingClass = nil
            } onReset: {
                model.rosterOverrides.removeValue(forKey: cls.id)
                model.persist()
                editingClass = nil
            } onCancel: {
                editingClass = nil
            }
        }
    }

    private var currentSoundName: String {
        SoundTheme.resolve(model.soundStyle)?.title ?? "每次随机"
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.1"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "34"
        return "v\(v) (\(b))"
    }

    private var copyright: String {
        let s = Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? ""
        return s.isEmpty ? "Copyright © 2026 Joy Ren. All rights reserved." : s
    }

    private func confirmClearHistory() {
        guard !model.history.isEmpty else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "清空全部历史记录？"
        alert.informativeText = "将删除 \(model.history.count) 条记录，点名统计随之清零。此操作不能撤销。"
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn { model.clearHistory() }
    }

    private func importRosterViaPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "randomroster"), .json].compactMap { $0 }
        panel.message = "选择名单文件（.randomroster 或 .json）"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let result = model.loadRoster(url: url)
        let alert = NSAlert()
        alert.alertStyle = result.ok ? .informational : .warning
        alert.messageText = result.ok ? "名单已导入" : "导入失败"
        alert.informativeText = result.message
        alert.runModal()
    }
}

// MARK: - 名单微调面板

struct RosterSheet: View {
    let cls: ClassRoster.SchoolClass
    @Binding var draft: String
    let onSave: () -> Void
    let onReset: () -> Void
    let onCancel: () -> Void

    private var count: Int {
        draft.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(cls.title) · 名单微调")
                    .font(.system(size: Type.cardTitle, weight: .bold))
                Text("一行一个姓名，行序即座位学号。当前 \(count) 人。")
                    .font(.system(size: Type.caption))
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $draft)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.semantic(.textBackground),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.semantic(.separator), lineWidth: 0.5)
                }

            HStack {
                Button("恢复导入名单", role: .destructive) { onReset() }
                Spacer()
                Button("取消") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("保存生效") { onSave() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 440, height: 520)
    }
}
