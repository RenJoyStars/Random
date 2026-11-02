import AppKit
import Foundation

// 生成 1024×1024 应用图标母版（原创设计：蓝底 + 五点骰面）
// 用法： swiftc -O -o MakeIcon MakeIcon.swift && ./MakeIcon 输出.png
//        ./MakeIcon --ios 输出.png   # iOS 版：满幅方形、无圆角（圆角由系统加）、无透明像素

let side: CGFloat = 1024
let iosMode = CommandLine.arguments.contains("--ios")

// ⚠️ iOS 的 App 图标**不能带 alpha 通道**（哪怕像素全不透明）。
// 带 alpha 的 PNG 被 iOS 判定为非法图标，桌面直接显示成白板。
// 所以 iOS 模式生成 3 通道（RGB）位图；macOS 图标要圆角外的透明，保持 4 通道。
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(side), pixelsHigh: Int(side),
    bitsPerSample: 8, samplesPerPixel: iosMode ? 3 : 4,
    hasAlpha: !iosMode, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

// 1) 底：macOS 裁圆角；iOS 满幅方（iOS 图标不许自带圆角与透明，系统会自己加）
let radius = side * 0.2237
let bg = CGPath(roundedRect: CGRect(x: 0, y: 0, width: side, height: side),
                cornerWidth: radius, cornerHeight: radius, transform: nil)
let square = CGPath(rect: CGRect(x: 0, y: 0, width: side, height: side), transform: nil)
ctx.saveGState()
ctx.addPath(iosMode ? square : bg)
ctx.clip()
let colors = [
    NSColor(srgbRed: 0.290, green: 0.518, blue: 1.000, alpha: 1).cgColor,
    NSColor(srgbRed: 0.086, green: 0.250, blue: 0.850, alpha: 1).cgColor
] as CFArray
if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                         colors: colors, locations: [0, 1]) {
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: 0, y: side),
                           end: CGPoint(x: side, y: 0),
                           options: [])
}
ctx.restoreGState()

// 2) 五点骰面（白）
let pipR = side * 0.0875
let near: CGFloat = 0.2925
let far: CGFloat = 0.7075
let points: [(CGFloat, CGFloat)] = [
    (0.5, 0.5), (near, near), (far, near), (near, far), (far, far)
]
ctx.setFillColor(NSColor.white.cgColor)
for (px, py) in points {
    let c = CGPoint(x: side * px, y: side * py)
    ctx.fillEllipse(in: CGRect(x: c.x - pipR, y: c.y - pipR,
                               width: pipR * 2, height: pipR * 2))
}

// 3) 收尾
NSGraphicsContext.restoreGraphicsState()

// 输出路径 = 第一个不以 -- 开头的参数
let out = CommandLine.arguments.dropFirst().first { !$0.hasPrefix("--") } ?? "icon_1024.png"
guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
