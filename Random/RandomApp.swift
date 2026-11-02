import SwiftUI

@main
struct RandomApp: App {
    // 用单例：见 AppModel.shared 的说明（写成 AppModel() 会造出多个实例，状态各自为政）
    @State private var model = AppModel.shared
    @AppStorage("appearance") private var appearance: String = "system"

    @NSApplicationDelegateAdaptor(RandomAppDelegate.self) private var appDelegate

    init() {
        // 让文件打开代理能拿到模型（双击 .randomroster 文件时调用）
        appDelegate.model = model
    }

    var body: some Scene {
        WindowGroup {
            rootView
        }
        .defaultSize(width: 1040, height: 760)
        .windowResizability(.contentMinSize)
        .commands { appCommands }

        Settings {
            settingsView
        }
    }

    private var rootView: some View {
        RootView()
            .environment(model)
            .preferredColorScheme(colorScheme)
            // ⚠️ 这个下限就是窗口能拖到多小 —— `.windowResizability(.contentMinSize)`
            // 会把这里的 minWidth 直接当成窗口下限。写 340 的时候窗口能被拖成
            // 343pt 宽：边栏挤成 90pt、内容顶出窗口、工具栏按钮全进溢出菜单。
            // 双栏布局要放得下边栏（212 起）+ 内容（≈540），780 是实测的底线。
            .frame(minWidth: RootView.minWindowWidth,
                   minHeight: RootView.minWindowHeight)
    }

    private var settingsView: some View {
        SettingsView()
            .environment(model)
            .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    // MARK: 菜单

    @CommandsBuilder
    private var appCommands: some Commands {
        CommandGroup(replacing: .newItem) {}

        CommandMenu("抽取") {
            Button(model.actionTitle) { model.performPrimaryAction() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.selection == .tool(.rockPaperScissors))

            // ⌘R：讲台上「再来一次」是最常做的一件事。
            // 用 ⌘R 而不是空格 —— 空格是文本框里的正常输入，绑成快捷键会把输入吃掉。
            Button("再抽一次") { model.performPrimaryAction() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(model.isRolling || model.selection == .settings || model.selection == .history)

            Button("撤销上一次") { model.undoCurrent() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!model.canUndo)

            Divider()

            Button(model.soundOn ? "关闭音效" : "打开音效") { model.soundOn.toggle() }
                .keyboardShortcut("m", modifiers: [.command, .shift])

            Divider()

            Button("清空当前记录") {
                withAnimation(.snappy(duration: 0.2)) { model.resetCurrent() }
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
            .disabled(!model.hasRecords)
        }

        CommandMenu("班级") {
            ForEach(Array(model.activeClasses.prefix(9).enumerated()), id: \.element.id) { index, cls in
                Button("\(cls.title) · \(cls.count) 人") {
                    withAnimation(.snappy(duration: 0.18)) {
                        model.selection = .classroom(cls.id)
                    }
                }
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
            }
        }

        CommandGroup(after: .sidebar) {
            Button("下一项") { model.step(1) }
                .keyboardShortcut("]", modifiers: .command)
            Button("上一项") { model.step(-1) }
                .keyboardShortcut("[", modifiers: .command)
        }
    }

    /// 处理「双击 / 拖到 Dock 图标」打开的名单文件。
    private class RandomAppDelegate: NSObject, NSApplicationDelegate {
        var model: AppModel?

        func application(_ application: NSApplication, open urls: [URL]) {
            guard let url = urls.first else { return }
            guard let result = model?.loadRoster(url: url) else { return }
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.alertStyle = result.ok ? .informational : .warning
                alert.messageText = result.ok ? "名单已导入" : "导入失败"
                alert.informativeText = result.message
                alert.runModal()
            }
        }
    }
}
