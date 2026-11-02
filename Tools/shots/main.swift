import SwiftUI
import AppKit

// 离屏渲染核对图：不依赖显示器、不需要解锁屏幕，直接把界面渲染成 PNG。
//
// 用法：./render-shots.sh [输出目录]
// 编译时排除 RandomApp.swift（它有 @main），由本文件充当程序入口。
//
// 两条渲染路径，各司其职：
//   · 页面 → NSHostingView + cacheDisplay，走真实 AppKit 渲染，
//     ScrollView / Form / 开关这些 AppKit 支撑的控件才能画出来
//     （ImageRenderer 画不出 ScrollView，整页会是空白）
//   · 彩带层 → ImageRenderer（纯 Canvas，透明背景），量出卡片位置后裁进去再合成
//     （锁屏时没有显示链接，TimelineView 的动画推不动，所以取静止帧）

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./build/shots"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

@MainActor
func appearance(_ scheme: ColorScheme) -> NSAppearance {
    NSAppearance(named: scheme == .dark ? .darkAqua : .aqua) ?? NSAppearance.currentDrawing()
}

/// 页面快照：交给 AppKit 真渲染，ScrollView / Form / 开关这些 AppKit 支撑的控件才出得来。
@MainActor
func pageImage(_ view: some View, size: CGSize, scheme: ColorScheme,
               wait: TimeInterval = 0.10) -> NSImage? {
    let host = NSHostingView(rootView: AnyView(
        // 铺一层的窗口背景：不加这层，深色页面外围是白的，
        // 次级小标题（它是 primary 色）就变成白底白字，图上看不见。
        view.environment(shotModel)
            .environment(\.colorScheme, scheme)
            .frame(width: size.width, height: size.height)
            .background(Color.semantic(.windowBackground))
    ))
    host.frame = CGRect(origin: .zero, size: size)

    var image: NSImage?
    appearance(scheme).performAsCurrentDrawingAppearance {
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(wait))
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        let out = NSImage(size: size)
        out.addRepresentation(rep)
        image = out
    }
    return image
}

/// 透明层快照（彩带）：ImageRenderer 对纯 Canvas 支持很好
@MainActor
func layerImage(_ view: some View, size: CGSize, scheme: ColorScheme) -> NSImage? {
    let renderer = ImageRenderer(content:
        view.environment(\.colorScheme, scheme)
            .frame(width: size.width, height: size.height)
    )
    renderer.scale = 2
    renderer.isOpaque = false
    var image: NSImage?
    appearance(scheme).performAsCurrentDrawingAppearance {
        image = renderer.nsImage
    }
    return image
}

/// 自动量出结果卡片的矩形：卡片底色和页面底色相同，只有那条细边框会被认出来。
/// 做法是在 x=100pt 这列上找"细而孤立"的深色行——上下边框各一条，
/// 按钮、记录胶囊这些厚实的内容会被过滤掉。（锁屏时截不了图，只能这样量）
@MainActor
func cardRect(in image: NSImage) -> CGRect? {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    let scale = CGFloat(rep.pixelsWide) / image.size.width
    let column = Int(100 * scale)
    guard let bg = rep.colorAt(x: column, y: 3)?.brightnessComponent else { return nil }

    var groups: [(Int, Int)] = []
    var start: Int?
    for y in 3..<Int(Double(rep.pixelsHigh) * 0.6) {
        let v = rep.colorAt(x: column, y: y)?.brightnessComponent ?? bg
        let deviates = abs(v - bg) > 0.02
        if deviates, start == nil { start = y }
        if !deviates, let s = start { groups.append((s, y - 1)); start = nil }
    }
    let thin = groups.filter { $0.1 - $0.0 <= Int(6 * scale) }
    guard thin.count >= 2 else { return nil }

    let top = CGFloat(thin[0].0) / scale
    let bottom = CGFloat(thin[1].1) / scale
    // 内缩 1pt，别把卡片自己的边框盖掉
    return CGRect(x: 21, y: top + 1, width: image.size.width - 42,
                  height: max(10, bottom - top - 2))
}

/// 把彩带层放进卡片的圆角范围里（应用里彩带就铺在结果卡片上、并被卡片裁掉外溢）
@MainActor
func placeLayer(_ layer: NSImage, into card: CGRect, radius: CGFloat, canvas: CGSize) -> NSImage {
    let out = NSImage(size: canvas)
    out.lockFocus()
    // lockFocus 的坐标原点是左下角，量出来的 card 是按左上角算的，这里翻一下 Y
    let target = CGRect(x: card.minX, y: canvas.height - card.maxY,
                        width: card.width, height: card.height)
    NSBezierPath(roundedRect: target, xRadius: radius, yRadius: radius).addClip()
    layer.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
    out.unlockFocus()
    return out
}

@MainActor
func save(_ image: NSImage, _ name: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("  ❌ \(name) 编码失败"); return
    }
    let path = (outDir as NSString).appendingPathComponent(name)
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("  ✅ \(name)  \(rep.pixelsWide)×\(rep.pixelsHigh)  \(png.count / 1024) KB")
    } catch {
        print("  ❌ \(name) 写入失败: \(error)")
    }
}

@MainActor
func overlay(_ base: NSImage, _ over: NSImage) -> NSImage {
    let out = NSImage(size: base.size)
    out.lockFocus()
    let rect = CGRect(origin: .zero, size: base.size)
    base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    over.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    out.unlockFocus()
    return out
}

/// 渲染一个页面；给了 `confettiAt` 就叠一层该时刻的彩带，裁进结果卡片里
@MainActor
func shot(_ name: String, _ view: some View, size: CGSize, scheme: ColorScheme,
          confettiAt t: Double? = nil, wait: TimeInterval = 0.10) {
    guard let base = pageImage(view, size: size, scheme: scheme, wait: wait) else {
        print("  ❌ \(name) 渲染失败"); return
    }
    guard let t else { save(base, name); return }

    guard let card = cardRect(in: base),
          // 彩带按“卡片”尺寸生成 —— 应用里的 Canvas 就铺在卡片上
          let layer = layerImage(ConfettiFrame(particles: ConfettiBurst.makeParticles(.confetti), t: t),
                                 size: card.size, scheme: scheme) else {
        print("  ⚠️ \(name) 未量出卡片，跳过彩带")
        save(base, name); return
    }
    save(overlay(base, placeLayer(layer, into: card, radius: 22, canvas: size)), name)
}

// MARK: - 状态与出图

/// 应用不再内置名单，渲染前灌一份演示名单。
/// 姓名用「班号-学号」生成：既便于核对，也不会把真实学生姓名带进出图。
let shotRoster: [ClassRoster.SchoolClass] = (2601...2606).map { id in
    ClassRoster.SchoolClass(id: String(id), names: (1...49).map { "\(id)-\($0)" })
}

// 离屏渲染也不能碰真实名单：给个临时路径（同 Tests/main.swift 的理由）
let shotModel = AppModel(
    autoloadImported: false, seedRoster: shotRoster, seedName: "演示名单",
    rosterStore: FileManager.default.temporaryDirectory
        .appendingPathComponent("random-shot-\(UUID().uuidString).randomroster")
)

@MainActor
func renderAll() {
    let wide = CGSize(width: 828, height: 880)
    let mid  = CGSize(width: 828, height: 700)

    shotModel.padZero = true
    shotModel.noRepeat = true
    shotModel.pickCount = 1
    shotModel.soundOn = true
    shotModel.classID = "2601"
    shotModel.drawnByClass = ["2601": [1, 3, 7, 12, 19, 23, 28, 33], "2604": [2, 9]]

    print("离屏渲染 → \(outDir)")

    // 0) 未导入名单时的空状态（应用第一次打开的样子）
    shot("空状态-未导入名单.png", NoRosterView(), size: wide, scheme: .light)

    // 1) 班级 · 单人 · 浅色
    shotModel.pickResults = [7]
    shotModel.pickMessage = shotModel.announcement(for: [7])
    shot("班级-单人-浅色.png", ClassroomView(), size: wide, scheme: .light)

    // 2) 班级 · 单人 · 深色 + 彩带（落定后 0.32 秒的那一帧）
    shot("班级-单人-深色-彩带.png", ClassroomView(), size: wide, scheme: .dark, confettiAt: 0.32)

    // 3) 班级 · 同时点 3 人
    shotModel.pickCount = 3
    shotModel.pickResults = [3, 12, 28]
    shotModel.pickMessage = shotModel.announcement(for: [3, 12, 28])
    shot("班级-多人-浅色.png", ClassroomView(), size: wide, scheme: .light)

    shotModel.pickCount = 1
    shotModel.pickResults = [7]
    shotModel.pickMessage = shotModel.announcement(for: [7])

    // 3.5) 班级 · 点名进行中：看扫描线和名字滚轮
    shotModel.pickRolling = true
    shot("班级-点名中-浅色.png", ClassroomView(), size: wide, scheme: .light, wait: 0.35)
    shot("班级-点名中-深色.png", ClassroomView(), size: wide, scheme: .dark, wait: 0.35)
    shotModel.pickRolling = false

    // 4) 随机数字：新的数字输入框 + 彩带
    shotModel.numResults = [17, 42, 88]
    shotModel.numCount = 3
    shot("随机数字-浅色.png", RandomNumberView(), size: mid, scheme: .light, confettiAt: 0.30)

    // 5) 骰子：数字输入框
    shotModel.diceCount = 3
    shotModel.diceFaces = 6
    shotModel.diceValues = [5, 2, 6]
    shot("骰子-浅色.png", DiceView(), size: CGSize(width: 828, height: 640), scheme: .light)

    // 6) 抽卡：数字输入框
    shotModel.cardDrawCount = 3
    shotModel.cards = [PlayingCard(rank: "A", suit: .spade),
                       PlayingCard(rank: "10", suit: .heart),
                       PlayingCard(rank: "K", suit: .diamond)]
    shot("抽卡-浅色.png", CardView(), size: mid, scheme: .light, wait: 0.9)

    // 6.1) 硬币：正面
    shotModel.coinIsHeads = true
    shot("硬币-正-浅色.png", CoinView(), size: CGSize(width: 828, height: 660), scheme: .light)

    // 6.2) 猜拳：石头 vs 剪刀
    shotModel.myMove = .rock
    shotModel.aiMove = .scissors
    shot("猜拳-浅色.png", RPSView(), size: CGSize(width: 828, height: 720), scheme: .light)

    // 6.3) 随机颜色
    shot("颜色-浅色.png", ColorView(), size: CGSize(width: 828, height: 620), scheme: .light)

    // 6.4) 随机字母
    shotModel.letterResult = "k"
    shot("字母-浅色.png", LetterView(), size: CGSize(width: 828, height: 640), scheme: .light)

    // 6.5) 是或否
    shotModel.yesNoResult = true
    shot("是否-浅色.png", YesNoView(), size: CGSize(width: 828, height: 660), scheme: .light)

    // 6.5) 随机分组（2.0）
    shotModel.classID = "2601"
    shotModel.groupMode = .byGroups
    shotModel.groupCount = 4
    shotModel.groupShowNumbers = true
    shotModel.groups = shotModel.nextGroups()
    shot("分组-浅色.png", GroupingView(), size: CGSize(width: 828, height: 800), scheme: .light)

    // 6.55) 分组洗牌中：看那几摞牌在桌上来回推
    shotModel.groupingRolling = true
    shot("分组-洗牌中-浅色.png", GroupingView(), size: CGSize(width: 828, height: 800), scheme: .light)
    shotModel.groupingRolling = false

    // 6.56) 随机顺序：洗牌中（前三位一起滚）+ 落定
    shotModel.sequenceResult = shotModel.shuffledOrder()
    shotModel.sequenceRolling = true
    shot("顺序-洗牌中-浅色.png", SequenceView(), size: CGSize(width: 828, height: 820), scheme: .light)
    shotModel.sequenceRolling = false
    shot("顺序-浅色.png", SequenceView(), size: CGSize(width: 828, height: 820), scheme: .light)
    shot("顺序-深色.png", SequenceView(), size: CGSize(width: 828, height: 820), scheme: .dark)

    // 6.6) 历史记录（2.0）：灌几条演示记录，看时间线与统计
    shotModel.history = []
    let now = Date()
    shotModel.logHistory(kind: HistoryKind.pick, classID: "2601", numbers: [7],
                         text: "07 2601-7", at: now.addingTimeInterval(-95))
    shotModel.logHistory(kind: HistoryKind.pick, classID: "2601", numbers: [3, 12],
                         text: "03 2601-3、12 2601-12", at: now.addingTimeInterval(-60))
    shotModel.logHistory(kind: HistoryKind.group, classID: "2601",
                         text: "4 组（13、12、12、12 人）", at: now.addingTimeInterval(-30))
    shotModel.logHistory(kind: Tool.dice.rawValue, text: "5 + 2 + 6 = 13",
                         at: now.addingTimeInterval(-8))
    shot("历史-浅色.png", HistoryView(), size: CGSize(width: 828, height: 860), scheme: .light)

    // 7) 设置页：音效开关（设置窗固定 540×540，长表单靠滚动，这里按实际窗口取景）
    shot("设置-音效.png", SettingsView(), size: CGSize(width: 540, height: 560), scheme: .dark)

    // 8) 整窗：验证「按宽度自适应布局」——窄走二级导航、宽走双栏
    shotModel.selection = .classroom("2601")
    shotModel.pickResults = [7]
    shotModel.pickMessage = shotModel.announcement(for: [7])
    shot("整窗-窄420.png", RootView(), size: CGSize(width: 420, height: 860), scheme: .light)
    shot("整窗-中680.png", RootView(), size: CGSize(width: 680, height: 760), scheme: .light)
    shot("整窗-宽1040.png", RootView(), size: CGSize(width: 1040, height: 760), scheme: .light)

    print("完成")
}

MainActor.assumeIsolated { renderAll() }
