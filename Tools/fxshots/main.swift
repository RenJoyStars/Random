import SwiftUI
import AppKit

// 特效离屏渲染：把 24 种落定特效各画一帧 PNG，用来逐个核对
//   1) 这一帧真的画出了东西（非背景像素占比够）
//   2) 粒子没有全部飞出画面（那等于没效果）
// 用法：FxRenderer [输出目录] [时间点]
//
// 之所以要单独做这个工具：特效是 Canvas + 时间轴画的，编译通过只说明语法对，
// 参数填错（速度 0、重力为 0、起点在画面外）只有渲染出来才看得见。

MainActor.assumeIsolated {
    let args = CommandLine.arguments
    let outDir = args.count > 1 ? args[1] : "./build/fx"
    let times: [Double] = args.count > 2
        ? args[2].split(separator: ",").compactMap { Double($0) }
        : [0.55]

    try? FileManager.default.createDirectory(atPath: outDir,
                                             withIntermediateDirectories: true)

    let W: CGFloat = 520, H: CGFloat = 340
    let bg = Color(red: 0.10, green: 0.11, blue: 0.14)

    for theme in CelebrationTheme.allCases {
        // 粒子是随机生成的：先建一次，多个时刻共用同一批，帧与帧之间才可比
        let particles = ConfettiBurst.makeParticles(theme)

        var report: [String] = []
        for t in times {
            let view = ConfettiFrame(particles: particles, t: t, theme: theme)
                .frame(width: W, height: H)
                .background(bg)

            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let img = renderer.nsImage,
                  let tiff = img.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                report.append("t=\(t) 渲染失败")
                continue
            }

            let name = times.count > 1
                ? "\(theme.rawValue)-t\(String(format: "%.2f", t)).png"
                : "\(theme.rawValue).png"
            try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
            report.append("t=\(String(format: "%.2f", t)) 覆盖 \(coverage(rep))%")
        }

        print("\(theme.rawValue.padding(toLength: 14, withPad: " ", startingAt: 0)) "
              + report.joined(separator: "  ") + "  (\(particles.count) 粒)")
    }
    print("输出目录：\(outDir)")
}

/// 非背景像素占比（粗估画面里到底有没有东西）。
/// 背景是固定的深灰蓝，任何比它亮/比它彩的像素都算「画上了」。
func coverage(_ rep: NSBitmapImageRep) -> Int {
    let w = rep.pixelsWide, h = rep.pixelsHigh
    guard w > 0, h > 0 else { return 0 }
    var hit = 0
    let step = 3
    var total = 0
    for y in stride(from: 0, to: h, by: step) {
        for x in stride(from: 0, to: w, by: step) {
            total += 1
            guard let c = rep.colorAt(x: x, y: y) else { continue }
            // 背景约 (0.10, 0.11, 0.14)；偏离它超过阈值就算有内容
            let d = abs(c.redComponent - 0.10)
                  + abs(c.greenComponent - 0.11)
                  + abs(c.blueComponent - 0.14)
            if d > 0.12 { hit += 1 }
        }
    }
    return total > 0 ? Int(Double(hit) / Double(total) * 100) : 0
}
