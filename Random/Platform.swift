import SwiftUI
import AppKit

// MARK: - 平台垫层
//
// 收拢与 AppKit 打交道的零碎工具（语义色、剪贴板、窗口反查）。
// 2026-10 起本工程只构建 macOS，原先的 iOS 分支已全部移除。

// MARK: 语义色

enum SemanticColor {
    case windowBackground, controlBackground, separator, textBackground
}

extension Color {
    /// 系统语义色，深浅色都自动跟随。
    static func semantic(_ s: SemanticColor) -> Color {
        switch s {
        case .windowBackground:  return Color(nsColor: NSColor.windowBackgroundColor)
        case .controlBackground: return Color(nsColor: NSColor.controlBackgroundColor)
        case .separator:         return Color(nsColor: NSColor.separatorColor)
        case .textBackground:    return Color(nsColor: NSColor.textBackgroundColor)
        }
    }
}

// MARK: 剪贴板

enum Pasteboard {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: HSB → RGB
// 纯算术，不依赖 AppKit；实测与 NSColor 的换算在 3000 组随机取样里仅 1 组差 1/255（舍入边界）。

func hsbToRGB(h: Double, s: Double, b: Double) -> (Double, Double, Double) {
    // ⚠️ 必须先挡 NaN / ±inf：h/s/b 可能来自外部文本解析（历史记录 / 导入数据），
    // 而 `Double("nan")`、`Double("inf")` 都是**合法解析结果**（不是 nil）。
    // 不挡的话下面 `Int(hue)` 会直接 trap 崩溃 —— 一行畸形数据就能让 App 挂掉。
    guard h.isFinite, s.isFinite, b.isFinite else { return (0, 0, 0) }
    let sat = min(max(s, 0), 1)
    let bri = min(max(b, 0), 1)

    let hue = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
    let c = bri * sat
    let x = c * (1 - abs(hue.truncatingRemainder(dividingBy: 2) - 1))
    let m = bri - c
    let rgb: (Double, Double, Double)
    switch Int(hue) {
    case 0:  rgb = (c, x, 0)
    case 1:  rgb = (x, c, 0)
    case 2:  rgb = (0, c, x)
    case 3:  rgb = (0, x, c)
    case 4:  rgb = (x, 0, c)
    default: rgb = (c, 0, x)
    }
    return (rgb.0 + m, rgb.1 + m, rgb.2 + m)
}

// MARK: 窗口尺寸相关

/// 不参与命中测试的容器视图。
/// representable 只是借它拿到窗口，但它会被拉伸到整块内容区 ——
/// 普通 NSView 会挡住鼠标事件，所以必须让点击穿透。
final class PassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// 盖掉窗口的最小尺寸。
///
/// SwiftUI 没有「显式指定窗口最小尺寸」的 API：`.windowResizability(.contentMinSize)`
/// 会把内容的固有最小宽度当成窗口下限。3.0 起我们不再做「窄窗口单栏」模式，
/// 所以下限就老老实实取「边栏 + 内容都放得下」的宽度（见 RootView.minWindowWidth）。
/// 这里再兜一道 `NSWindow.minSize`：SwiftUI 每次布局都会重算 contentMinSize，
/// 单靠 view 上的 `.frame(minWidth:)` 偶尔会被它盖掉，两道一起才稳。
struct WindowMinSizeSetter: NSViewRepresentable {
    var minSize: CGSize

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughView(frame: .zero)
        DispatchQueue.main.async { apply(to: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: nsView) }
    }

    private func apply(to view: NSView) {
        guard let window = view.window else { return }
        // 相等就不写，避免和 SwiftUI 互相覆盖成死循环
        if window.contentMinSize != minSize { window.contentMinSize = minSize }
        if window.minSize != minSize { window.minSize = minSize }
    }
}

/// 把宿主 `NSWindow` 交出来。
///
/// SwiftUI 不暴露窗口对象，但「投影模式切全屏」必须直接动窗口 ——
/// 只能借一个不参与命中测试的垫层 view 反查它挂在哪扇窗口上。
struct WindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.lastResolved = view.window
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // ⚠️ 必须做同值判断。调用方拿到窗口后会写自己的 `@State`，
        // 而无条件回调会形成「body → updateNSView → 写 @State → body」的自我维持循环：
        // 窗口一次都没变，重绘却停不下来，CPU 一直空转。
        // （同文件的 WindowMinSizeSetter 本来就做了同值保护，这里漏了。）
        let window = nsView.window
        guard window !== context.coordinator.lastResolved else { return }
        context.coordinator.lastResolved = window
        DispatchQueue.main.async { onResolve(window) }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator { var lastResolved: NSWindow? }
}

/// 单向汇报宿主窗口的宽度（窗口每被拖动一次就回调一次）。
///
/// 只做一件事：窄了就收起边栏。**宽回来不自动打开** ——
/// 打开边栏是老师主动点工具栏按钮的动作，App 不该替人做主。
/// 所以调用方拿到宽度后只有「窄」这个分支，没有 else。
struct WindowWidthReporter: NSViewRepresentable {
    var onChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughView(frame: .zero)
        context.coordinator.attach(to: view, onChange)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.attach(to: nsView, onChange)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private weak var window: NSWindow?
        private var observer: NSObjectProtocol?
        private var lastWidth: CGFloat = 0

        func attach(to view: NSView, _ onChange: @escaping (CGFloat) -> Void) {
            DispatchQueue.main.async { [weak self] in
                guard let self, let w = view.window else { return }
                if self.window !== w {
                    self.window = w
                    if let old = self.observer { NotificationCenter.default.removeObserver(old) }
                    self.observer = NotificationCenter.default.addObserver(
                        forName: NSWindow.didResizeNotification, object: w, queue: .main
                    ) { [weak self] _ in
                        guard let self, let window = self.window else { return }
                        self.report(window.frame.width, onChange)
                    }
                }
                // 刚挂上时先报一次：上次退出时窗口本来就窄，启动就该是收起的。
                self.report(w.frame.width, onChange)
            }
        }

        /// 同值保护：SwiftUI 每轮布局都会 updateNSView，不挡的话会一直写 @State。
        private func report(_ width: CGFloat, _ onChange: @escaping (CGFloat) -> Void) {
            guard abs(width - lastWidth) > 0.5 else { return }
            lastWidth = width
            onChange(width)
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
    }
}
