import SwiftUI
import UniformTypeIdentifiers

// MARK: - 设置（⌘,）

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("appearance") private var appearance: String = "system"
    @State private var editingClass: ClassRoster.SchoolClass?
    @State private var draft: String = ""

    var body: some View {
        Form {
            Section("外观") {
                Picker("主题", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.segmented)

                // 舞台字号（2.0）：只放大「结果」本身。
                // 整窗缩放会把侧边栏和按钮一起放大，投影时屏幕上反而更挤。
                LabeledContent("舞台字号") {
                    HStack(spacing: 10) {
                        Slider(value: model.binding(\.stageScale), in: 0.8...1.6)
                            .frame(width: 170)
                        Text("\(Int((model.effectiveStageScale * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                        Button("默认") { model.stageScale = 1.0 }
                            .controlSize(.small)
                            .disabled(abs(model.stageScale - 1.0) < 0.001)
                    }
                }
            }

            Section("班级点名") {
                Toggle("不重复（点过的本轮不再点）", isOn: model.binding(\.noRepeat))
                Toggle("补零显示（7 号显示为 07）", isOn: model.binding(\.padZero))
                LabeledContent("每次点几名") {
                    NumberField(value: model.binding(\.pickCount), suffix: "人", range: 1...10)
                }

                // 抽取节奏：8 种工具的滚动时长都由它乘出来（见 AppModel.finishAfter）。
                LabeledContent("抽取节奏") {
                    HStack(spacing: 10) {
                        Slider(value: model.binding(\.pickSpeed), in: 0.5...1.8)
                            .frame(width: 150)
                        Text(String(format: "%.1f 秒",
                                    0.95 * model.effectivePickSpeed))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .trailing)
                        Button("标准") { model.pickSpeed = 1.0 }
                            .controlSize(.small)
                            .disabled(abs(model.pickSpeed - 1.0) < 0.01)
                    }
                }
                Text("往左更快、往右更慢。点名学生看清滚动过程大约要 0.6 秒以上，再快就只剩「闪一下」。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("抽取音效", isOn: model.binding(\.soundOn))

                Text("每个工具用自己的过程音：骰子「咔啦」、硬币「叮」、洗牌「唰」、点名「嗒」、猜拳「呼」、打字机「嗒」。这里试听的是通用的鼓点。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("音量") {
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: model.binding(\.soundVolume), in: 0...1)
                            .frame(width: 150)
                        Text("\(Int((model.soundVolume * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                    }
                }
                .disabled(!model.soundOn)

                Picker("落定音风格", selection: model.binding(\.soundStyle)) {
                    Text("每次随机（\(SoundTheme.allCases.count) 种）")
                        .tag(SoundTheme.randomKey)
                    ForEach(SoundTheme.Family.allCases) { family in
                        Section(family.title) {
                            ForEach(family.themes) { theme in
                                Text(theme.title).tag(theme.rawValue)
                            }
                        }
                    }
                }
                .disabled(!model.soundOn)
                .onChange(of: model.soundStyle) { _, _ in
                    // 选完立刻听一耳朵，不用再点「试听」去猜
                    if model.soundOn { Sound.shared.victory() }
                }

                LabeledContent("试听") {
                    HStack(spacing: 8) {
                        Text(currentSoundName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("鼓点 + 落定音") { Sound.shared.preview() }
                            .controlSize(.small)
                            .disabled(!model.soundOn)
                    }
                }
            } header: {
                Text("音效")
            } footer: {
                Text("全部程序实时合成，不依赖任何音频文件、不联网。落定音共 \(SoundTheme.allCases.count) 种，分五族：打击 / 旋律 / 电子 / 自然 / 趣味；默认每次现场随机 —— 同一套铃声听一学期，学生两周就腻。")
                    .font(.caption)
            }

            Section {
                Picker("风格", selection: model.binding(\.celebrationStyle)) {
                    Text("每次随机（\(CelebrationTheme.allCases.count) 种）")
                        .tag(CelebrationTheme.randomKey)
                    ForEach(CelebrationTheme.Family.allCases) { family in
                        Section(family.title) {
                            ForEach(family.themes) { theme in
                                Text(theme.title).tag(theme.rawValue)
                            }
                        }
                    }
                }
                LabeledContent("当前") {
                    HStack(spacing: 6) {
                        Image(systemName: model.celebrationTheme.symbol)
                        Text(model.celebrationTheme.title)
                    }
                    .foregroundStyle(.secondary)
                }

                // 教室里的投影和老 Mac 未必扛得住满屏粒子，给老师一个降档开关。
                Picker("强度", selection: model.binding(\.effectLevel)) {
                    ForEach(EffectLevel.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
            } header: {
                Text("落定特效")
            } footer: {
                Text("点名 / 抽取落定时放一次，共 \(CelebrationTheme.allCases.count) 种：经典（礼炮 / 烟花 / 星芒 / 光环）、飘落（纸片 / 雪 / 花瓣 / 秋叶 / 金雨 / 蝴蝶）、涌动（爱心 / 气泡 / 喷泉 / 螺旋 / 漩涡）、光效（流星 / 霓虹 / 闪粉 / 金币 / 彗星）、爆发（新星 / 冲击波 / 像素 / 礼花）。默认每次随机。")
                    .font(.caption)
            }

            Section {
                Toggle("点名后读出姓名", isOn: Binding(
                    get: { Speech.shared.enabled },
                    set: { Speech.shared.enabled = $0 }
                ))
                Toggle("跟随系统朗读设置（与 VoiceOver 同款语音）", isOn: Binding(
                    get: { Speech.shared.followsSystemVoice },
                    set: { Speech.shared.followsSystemVoice = $0 }
                ))
                Text("开启后使用系统「朗读内容」里配的语音和语速，这里选的语音与语速就不生效了。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("语音", selection: Binding(
                    get: { Speech.shared.voiceIdentifier ?? "" },
                    set: { Speech.shared.voiceIdentifier = $0.isEmpty ? nil : $0 }
                )) {
                    Text("自动（挑质量最高的）").tag("")
                    ForEach(Speech.shared.voices, id: \.identifier) { v in
                        Text("\(Speech.displayName(v)) · \(v.language) · \(Speech.qualityLabel(v))").tag(v.identifier)
                    }
                }
                .disabled(Speech.shared.followsSystemVoice)
                Text("Siri 的声音被系统锁给 Apple 自家 App，第三方 App 拿不到，所以列表里不会有它 —— 想更自然就下载「增强 / 优质」档。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("当前使用") {
                    HStack(spacing: 10) {
                        Text(Speech.shared.currentVoiceDescription)
                            .foregroundStyle(.secondary)
                        Button("重新扫描") { Speech.shared.rescanVoices() }
                            .controlSize(.small)
                            .help("刚在系统设置里下载完语音的话，点这里立刻生效，不用重启 App")
                    }
                }
                if !Speech.hasHighQualityVoice {
                    Text("现在是「紧凑」档语音（系统预装，机械感明显）。"
                         + "想要更自然：系统设置 → 辅助功能 → 朗读内容 → 声音 → 中文 → 选一个 → 点云图标下载「增强」或「优质」版本（约 100–300 MB），下载后点上面的「重新扫描」就能选到。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                LabeledContent("语速 \(String(format: "%.2f", Speech.shared.rate))") {
                    Slider(value: Binding(
                        get: { Speech.shared.rate },
                        set: { Speech.shared.rate = $0 }
                    ), in: 0.3...0.6)
                    .frame(minWidth: 160, maxWidth: 240)
                    .disabled(Speech.shared.followsSystemVoice)
                }
                LabeledContent("试听") {
                    Button("播放") { Speech.shared.speak("张三") }
                        .controlSize(.small)
                        .disabled(!Speech.shared.enabled)
                }
            } header: {
                Text("朗读")
            } footer: {
                Text("点名后直接念出姓名（如「张三」，多人用顿号连读）。用系统语音引擎，免联网、免权限。")
                    .font(.caption)
            }

            Section {
                if model.hasClasses {
                    LabeledContent("当前名单",
                                   value: model.importedRosterName.map { "已导入：\($0)" } ?? "已导入名单")
                    LabeledContent("规模",
                                   value: "\(model.activeClasses.count) 个班 · 共 \(model.activeClasses.reduce(0) { $0 + $1.count }) 人")
                    Button("重新导入名单文件…") { importRosterViaPanel() }
                        .controlSize(.small)
                    Button("移除名单", role: .destructive) {
                        withAnimation(.snappy(duration: 0.2)) { model.clearRoster() }
                    }
                    .controlSize(.small)
                } else {
                    Text("尚未导入名单 —— 导入后才能开始点名。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("导入名单文件…") { importRosterViaPanel() }
                        .controlSize(.small)
                }
            } header: {
                Text("名单来源")
            } footer: {
                Text("把任意 Excel 交给 AI 转成 .randomroster 文件，即可导入、也能分享给其他老师。应用本身不含任何名单，换台电脑导入一次即可。")
                    .font(.caption)
            }

            if model.hasClasses {
                Section {
                    ForEach(model.activeClasses) { cls in
                        LabeledContent(cls.title) {
                            HStack(spacing: 10) {
                                Text("\(model.names(of: cls.id).count) 人")
                                    .foregroundStyle(.secondary)
                                Text("已抽 \(model.drawnCount(of: cls.id))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if model.rosterOverrides[cls.id] != nil {
                                    Text("已自定义")
                                        .font(.caption)
                                        .foregroundStyle(Color.accentColor)
                                }
                                Button("查看 / 微调") {
                                    draft = model.names(of: cls.id).joined(separator: "\n")
                                    editingClass = cls
                                }
                                .controlSize(.small)
                            }
                        }
                    }
                } header: {
                    Text("班级名单")
                } footer: {
                    Text("如需修正个别姓名，可在此微调（仅影响本机，不改变导入文件）。")
                        .font(.caption)
                }
            }

            Section("数据") {
                LabeledContent("历史记录", value: "\(model.history.count) 条")
                Button("清空所有班级的点名记录") {
                    withAnimation(.snappy(duration: 0.2)) {
                        model.drawnByClass = [:]
                        model.pickResults = []
                        model.lastDrawn = []
                        model.persist()
                    }
                }
                Button("清空历史记录（含点名统计）") { confirmClearHistory() }
                Button("清除名单的手动微调", role: .destructive) {
                    model.rosterOverrides = [:]
                    model.persist()
                }
            }

            Section {
                LabeledContent("版本", value: appVersion)
                LabeledContent("版权", value: copyright)
                LabeledContent("标识", value: "cn.renqiaoyi.random")
            } header: {
                Text("关于")
            } footer: {
                Text("Random 是班级随机抽选工具，不含任何内置名单，导入自己的名单即可使用。所有数据只保存在本机，应用不联网、不上传。")
                    .font(.caption)
            }
        }
        // 用系统 group 化的 Form，**不换背景**。
        // 之前这里铺了一层蓝紫渐变（StageBackdrop），想让设置窗口和主窗口一个调子；
        // 但那让设置页变成了"另一个 app"：macOS 的设置窗口从来就是系统窗口底色，
        // 用户一眼就知道"这是设置"。`scrollContentBackground(.hidden)` 也一并去掉，
        // 交给系统决定深浅色下的底色。
        .formStyle(.grouped)
        .frame(width: 540, height: 560)
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

    /// 当前落定音的名字（「每次随机」时也照实说，别显示某一个具体音色）
    private var currentSoundName: String {
        SoundTheme.resolve(model.soundStyle)?.title ?? "每次随机"
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2"
        return "\(v) (\(b))"
    }

    /// 版权信息只写在 Info.plist 里（`NSHumanReadableCopyright`），界面从这里读，避免两处不一致。
    private var copyright: String {
        let s = Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? ""
        return s.isEmpty ? "Copyright © 2026 Joy. All rights reserved." : s
    }

    /// 清空历史要二次确认：它同时会清零班级页的「被点最少」统计。
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

    /// 打开文件面板导入名单（设置页的「导入外部名单文件…」用）。
    private func importRosterViaPanel() {        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "randomroster"), .json]
            .compactMap { $0 }
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
                Text("\(cls.title) · 名单")
                    .font(.headline)
                Text("一行一个姓名，行序即学号。当前 \(count) 人。")
                    .font(.caption)
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
                Button("恢复导入的名单", role: .destructive) { onReset() }
                Spacer()
                Button("取消") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") { onSave() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 420, height: 520)
    }
}
