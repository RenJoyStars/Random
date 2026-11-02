import AVFoundation
import Foundation

// MARK: - 音效
//
// 全部**程序合成**，不依赖任何音频资源文件：需要什么样的声音，就把 PCM 采样算出来。
//
// 三类声音：
//   · tick(progress:)  抽取过程中的小鼓「哒哒哒」，越到后面越密、越响
//   · ding()           普通工具落定的一记轻响
//   · victory()        点名 / 抽取落定的胜利音
//
// **3.3 起每个工具有自己的过程音**（见 `ToolSound`）：骰子是骰子滚桌、硬币是
// 金属叮、抽卡是洗牌唰、猜拳是挥手的呼、点名是木牌嗒。原来八种工具共用一套
// 嘟嘟嘟，切换工具听不出区别 —— 声音是「这是什么工具」最快的提示。
//
// 落定音有 **25 种**（3.0 起），分五个族：打击 / 旋律 / 电子 / 自然 / 趣味。
// 默认每次现场随机挑一种 —— 同一套铃声用一学期，学生听两周就腻了。
//
// 所有音色都由 `synth(...)` 一个通用合成器算出来：给定「音高序列 + 波形 + 谐波 +
// 包络 + 滑音 + 噪声」，缺什么调什么。少数需要特殊包络的（掌声、弹簧）单独写。
//
// 总开关是**静态属性** `Sound.enabled`——关掉音效时连音频引擎都不会被创建。

/// 落定音的风格。设置页存 `rawValue`，`random` 表示每次现场抽。
enum SoundTheme: String, CaseIterable, Identifiable, Sendable {

    // 打击：一记 / 几记短促的敲击
    case bell, marimba, woodblock, tambourine
    // 旋律：有明确音高的和弦或音阶
    case arpeggio, piano, musicbox, harp, vibraphone, guitar, brass, horn
    // 电子：合成器 / 街机
    case whoosh, laser, chiptune, synthrise
    // 自然：水、风、人声、玻璃
    case waterdrop, bubble, windchime, choir, glass
    // 趣味：课堂里能博一笑的
    case applause, heartbeat, boing, pop

    var id: String { rawValue }

    /// 五个族，设置页按族分组显示（25 个平铺一列太长了）。
    enum Family: String, CaseIterable, Identifiable, Sendable {
        case percussion, melody, electronic, nature, fun

        var id: String { rawValue }

        var title: String {
            switch self {
            case .percussion: return "打击"
            case .melody:     return "旋律"
            case .electronic: return "电子"
            case .nature:     return "自然"
            case .fun:        return "趣味"
            }
        }

        /// 这一族里有哪些音色（顺序跟随 allCases）
        var themes: [SoundTheme] { SoundTheme.allCases.filter { $0.family == self } }
    }

    var family: Family {
        switch self {
        case .bell, .marimba, .woodblock, .tambourine:
            return .percussion
        case .arpeggio, .piano, .musicbox, .harp, .vibraphone, .guitar, .brass, .horn:
            return .melody
        case .whoosh, .laser, .chiptune, .synthrise:
            return .electronic
        case .waterdrop, .bubble, .windchime, .choir, .glass:
            return .nature
        case .applause, .heartbeat, .boing, .pop:
            return .fun
        }
    }

    var title: String {
        switch self {
        case .bell:       return "钟声"
        case .marimba:    return "木琴"
        case .woodblock:  return "木鱼"
        case .tambourine: return "铃鼓"
        case .arpeggio:   return "琶音"
        case .piano:      return "钢琴和弦"
        case .musicbox:   return "八音盒"
        case .harp:       return "竖琴"
        case .vibraphone: return "电颤琴"
        case .guitar:     return "吉他扫弦"
        case .brass:      return "铜管"
        case .horn:       return "号角"
        case .whoosh:     return "电子上扬"
        case .laser:      return "激光"
        case .chiptune:   return "像素游戏"
        case .synthrise:  return "合成上升"
        case .waterdrop:  return "水滴"
        case .bubble:     return "气泡"
        case .windchime:  return "风铃"
        case .choir:      return "人声"
        case .glass:      return "玻璃"
        case .applause:   return "掌声"
        case .heartbeat:  return "心跳"
        case .boing:      return "弹簧"
        case .pop:        return "弹跳"
        }
    }

    var symbol: String {
        switch self {
        case .bell:       return "bell.fill"
        case .marimba:    return "music.note"
        case .woodblock:  return "circle.grid.cross"
        case .tambourine: return "circle.dashed"
        case .arpeggio:   return "pianokeys"
        case .piano:      return "pianokeys.inverse"
        case .musicbox:   return "music.quarternote.3"
        case .harp:       return "guitars"
        case .vibraphone: return "waveform"
        case .guitar:     return "guitar.fill"
        case .brass:      return "trumpet.fill"
        case .horn:       return "megaphone.fill"
        case .whoosh:     return "waveform.path"
        case .laser:      return "bolt.fill"
        case .chiptune:   return "gamecontroller.fill"
        case .synthrise:  return "chart.line.uptrend.xyaxis"
        case .waterdrop:  return "drop.fill"
        case .bubble:     return "circle.hexagongrid.fill"
        case .windchime:  return "bell.and.waves.left.and.right"
        case .choir:      return "person.3.fill"
        case .glass:      return "cup.and.saucer.fill"
        case .applause:   return "hands.clap.fill"
        case .heartbeat:  return "heart.fill"
        case .boing:      return "arrow.up.and.down"
        case .pop:        return "sparkles"
        }
    }

    /// 设置页「随机」的键值
    static let randomKey = "random"

    /// 设置里存的字符串 → 风格。`random` / 不认识的一律返回 nil（= 每次随机）。
    static func resolve(_ key: String) -> SoundTheme? {
        key == randomKey ? nil : SoundTheme(rawValue: key)
    }
}

/// 每个工具自己的「抽取过程中」音色。
///
/// 这一层和 `SoundTheme` 分工不同：
///   · `SoundTheme` 是**落定**那一记（25 种，老师可选、默认现场随机）；
///   · `ToolSound` 是**过程中**那几十拍，必须和工具本身对得上 ——
///     骰子滚动时放钟声、硬币翻飞时放木鱼，再好的音色也是错的。
enum ToolSound: String, CaseIterable, Sendable {

    /// 点名：木牌「嗒」。这是老师在点名册上点名字的声音。
    case pick
    /// 随机数字：老式机械计数器的「嘀」。
    case number
    /// 骰子：塑料骰子在桌面上滚的「咔啦」。
    case dice
    /// 硬币：金属被弹起来、还在空中转的「叮」。
    case coin
    /// 抽卡：洗牌的「唰」。
    case card
    /// 颜色：取色器/调色盘很轻的「嘟」。
    case color
    /// 字母：打字机的「嗒」。
    case letter
    /// 猜拳：手往下挥的「呼」——三拍之后出拳。
    case rps
    /// 是或否：悬念的心跳。
    case yesNo
    /// 分组 / 打乱顺序：洗牌分堆。
    case shuffle

    /// 落定音用不用「自己的实物声」。
    ///
    /// 骰子、硬币、牌、猜拳、取色器都有确定的实物落定声，
    /// 这时候插一段八音盒会显得莫名其妙。抽象抽取（点名 / 数字 / 字母 /
    /// 是或否 / 分组 / 顺序）没有实物，仍然用设置里选的 25 种落定音。
    var hasOwnSettle: Bool {
        switch self {
        case .dice, .coin, .card, .rps, .color: return true
        case .pick, .number, .letter, .yesNo, .shuffle: return false
        }
    }
}


final class Sound {

    static let shared = Sound()

    /// 总开关（跟随 AppModel.soundOn）。关闭后所有发声调用直接返回。
    static var enabled: Bool = true

    /// 落定音风格。nil = 每次现场随机。
    static var themeStyle: SoundTheme?
    /// 抽取鼓点音色（0 木鼓 / 1 电子 / 2 心跳）。nil = 每轮随机。
    static var drumStyle: Int?

    /// 主音量 0…1。0.8 是「投影教室里够响、又不刺耳」的位置。
    static var volume: Float = 0.8 {
        didSet { Sound.shared.applyVolume() }
    }

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let sampleRate: Double = 44_100
    private let format: AVAudioFormat
    private var players: [AVAudioPlayerNode] = []
    private var cursor = 0
    private var running = false
    private var lastStartAttempt: Date = .distantPast
    private var previewTimer: Timer?

    /// 本轮用的鼓组（0…2），每轮开始换一套
    private var drumSet = 0
    /// 本轮的上扬音是否已经响过（每轮只响一次，别一直冲）
    private var riserPlayed = false
    /// 本轮点名/抽取用的是哪个工具的过程音（nil = 走旧的通用鼓点）
    private var roundTool: ToolSound?
    /// 本轮已经敲了几拍（点名要每 5 拍插一记沙锤，骰子要偶尔换个弹跳音高）
    private var roundBeat = 0

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(mixer)
        // 一组播放节点轮流用，短音效可以互相叠着响，不会互相打断。
        for _ in 0..<12 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: mixer, format: format)
            players.append(node)
        }
        engine.connect(mixer, to: engine.mainMixerNode, format: format)
    }

    private func applyVolume() {
        mixer.outputVolume = min(max(Sound.volume, 0), 1)
    }

    // MARK: - 对外接口

    /// 每次抽取开始时调用：换一套鼓点音色，并重新允许上扬音。
    ///
    /// 由 `AppModel.finishAfter` 统一调用 —— 8 个工具的抽取都走那里，
    /// 所以不用在每个 draw 函数里各写一遍。
    func beginRound() {
        drumSet = Int.random(in: 0..<3)
        if let fixed = Sound.drumStyle { drumSet = min(max(fixed, 0), 2) }
        riserPlayed = false
        roundTool = nil
        roundBeat = 0
    }

    /// 同上，但指定这一轮是哪个工具 —— 之后每次 `tick` 都用它自己的音色。
    func beginRound(_ tool: ToolSound) {
        beginRound()
        roundTool = tool
    }

    /// 抽取过程中的鼓点。`progress` 0…1，越接近 1 鼓点越亮越响。
    ///
    /// 传了 `tool` 就走那个工具自己的过程音；不传还是老的一套（设置页试听用）。
    func tick(_ progress: Double = 0.5, _ tool: ToolSound? = nil) {
        guard Sound.enabled else { return }

        let which = tool ?? roundTool
        let beat = roundBeat
        roundBeat += 1

        // 最后 22% 插一记上扬音（扫频 + 噪声），把紧张感顶上去。
        // 实物类工具（骰子/硬币/牌）不加：它们的声音本来就该一直是那个东西在响，
        // 突然插一段电子扫频会显得很假。
        let wantsRiser = !(which?.hasOwnSettle ?? false)
        if wantsRiser, progress >= 0.78, !riserPlayed {
            riserPlayed = true
            play(riserBuffer)
        }

        if let which {
            play(toolTick(which, step: progress, beat: beat))
            return
        }

        let list = drums[drumSet % drums.count]
        guard !list.isEmpty else { return }
        let i = min(list.count - 1, max(0, Int((progress * Double(list.count - 1)).rounded())))
        play(list[i])
    }

    /// 落定：实物类工具用自己的落地声，抽象抽取用设置里的 25 种落定音。
    ///
    /// 点名不要走这里 —— 它要配合语音播报，由 AppModel 显式调 `victory()`。
    func settle(_ tool: ToolSound) {
        guard Sound.enabled else { return }
        if tool.hasOwnSettle, let b = toolSettle(tool) {
            play(b)
        } else {
            victory()
        }
    }

    /// 落定轻响（硬币、字母这类小结果）
    func ding() {
        guard Sound.enabled else { return }
        play(dingBuffer)
    }

    /// 胜利音。风格按设置走；设置是「随机」时每次现场挑一个。
    func victory() {
        guard Sound.enabled else { return }
        let theme = Sound.themeStyle ?? (SoundTheme.allCases.randomElement() ?? .bell)
        play(victoryBuffer(for: theme))
    }

    /// 只播某一种（设置页点列表里的音色就听它）
    func play(theme: SoundTheme) {
        guard Sound.enabled else { return }
        play(victoryBuffer(for: theme))
    }

    /// 合成指定风格的落定音并交出来（不播放）。
    /// 设置页的逐个试听、以及无头自测「每个音色都真的出了声」都走这里。
    func buffer(for theme: SoundTheme) -> AVAudioPCMBuffer? {
        victoryBuffer(for: theme)
    }

    /// 设置页「试听」：一小段加速鼓点接一记胜利音
    func preview() {
        guard Sound.enabled else { return }
        previewTimer?.invalidate()
        beginRound()
        var p = 0.0
        previewTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if p >= 1 {
                timer.invalidate()
                self.victory()
                return
            }
            self.tick(p)
            p += 0.14
        }
    }

    // MARK: - 播放

    private func play(_ buffer: AVAudioPCMBuffer?) {
        guard Sound.enabled, let buffer else { return }
        guard start() else { return }
        applyVolume()
        let node = players[cursor % players.count]
        cursor = (cursor + 1) % players.count
        node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !node.isPlaying { node.play() }
    }

    /// 需要时才启动引擎；失败后 2 秒内不再重试，免得每 40ms 都去撞一次墙。
    private func start() -> Bool {
        if running && engine.isRunning { return true }
        running = false
        let now = Date()
        if now.timeIntervalSince(lastStartAttempt) < 2 { return false }
        lastStartAttempt = now
        do {
            engine.prepare()
            try engine.start()
            for node in players where !node.isPlaying { node.play() }
            running = true
        } catch {
            running = false
        }
        return running
    }

    // MARK: - 波形合成

    /// 基础波形。所有音色都由这四种（+ 噪声）拼出来。
    private enum Wave {
        case sine, square, saw, triangle

        func value(_ phase: Double) -> Double {
            switch self {
            case .sine:     return sin(2 * .pi * phase)
            case .square:   return sin(2 * .pi * phase) >= 0 ? 1 : -1
            case .saw:      return 2 * (phase - (phase + 0.5).rounded(.down))
            case .triangle: return 4 * abs(phase - (phase + 0.5).rounded(.down)) - 1
            }
        }
    }

    /// 把一段时间的波形渲染成 PCM 缓冲。`f` 收到的是时间（秒），返回 −1…1 的采样值。
    private func render(_ duration: Double, _ f: (Double) -> Double) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(max(1, (duration * sampleRate).rounded()))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            let v = f(Double(i) / sampleRate)
            channel[i] = Float(v.isFinite ? min(1, max(-1, v)) : 0)
        }
        return buffer
    }

    /// **通用合成器**：3.0 的 25 种音色里，20 种都是调它的参数拼出来的。
    ///
    /// - Parameters:
    ///   - duration: 总时长（秒）
    ///   - notes: 每个音的「起音时刻 + 频率」。多个音错开就是音阶 / 和弦 / 扫弦。
    ///   - decay: 指数衰减速度。越大收得越快（木琴 7.5 / 钟声 3.1 / 玻璃 0.9）。
    ///   - wave: 基础波形。方波更"街机"，锯齿更"铜管"，三角更"人声"。
    ///   - harmonics: 谐波 [(倍频, 幅度)]。2.76 这种非整数倍是钟 / 玻璃的金属感来源。
    ///   - glide: 频率终点倍数。1 = 不滑音；0.5 = 掉一个八度（水滴、激光用）。
    ///   - glideTime: 滑完所需时间（秒）。
    ///   - noise: 起音瞬间的噪声量（鼓皮、拨弦的"擦"声）。
    ///   - noiseDecay: 噪声衰减速度。
    ///   - amp: 总幅度。
    ///   - vibrato: 颤音深度（Hz）与速率（Hz/秒）。电颤琴、人声用。
    private func synth(_ duration: Double,
                       notes: [(onset: Double, freq: Double)],
                       decay: Double,
                       wave: Wave = .sine,
                       harmonics: [(Double, Double)] = [(1, 1)],
                       glide: Double = 1,
                       glideTime: Double = 0.3,
                       noise: Double = 0,
                       noiseDecay: Double = 200,
                       amp: Double = 0.55,
                       vibrato: Double = 0,
                       vibratoRate: Double = 5) -> AVAudioPCMBuffer? {
        render(duration) { t in
            var sum = 0.0
            for n in notes {
                let lt = t - n.onset
                guard lt >= 0 else { continue }

                var f = n.freq
                if glide != 1 {
                    let k = min(1, lt / max(0.01, glideTime))
                    f *= pow(glide, k)
                }
                if vibrato > 0 {
                    f += sin(2 * .pi * vibratoRate * lt) * vibrato
                }

                var v = 0.0
                for h in harmonics {
                    v += wave.value(f * h.0 * lt) * h.1
                }
                sum += v * exp(-lt * decay)
            }
            if noise > 0 {
                sum += Double.random(in: -1...1) * exp(-t * noiseDecay) * noise
            }
            return sum * amp
        }
    }

    // MARK: - 鼓点

    /// 小鼓点。三套音色，`intensity` 0…1 控制音高与音量。
    /// - set 0：木鼓（鼓皮噪声 + 鼓身，最经典）
    /// - set 1：电子（方波 + 高频 click，更"街机"）
    /// - set 2：心跳（低频 sine，厚重点）
    private func makeDrum(_ intensity: Double, set: Int) -> AVAudioPCMBuffer? {
        switch set {
        case 1:
            return render(0.055) { t in
                let env = exp(-t * 55)
                let p = 420 + 520 * intensity
                let square = sin(2 * .pi * p * t) >= 0 ? 1.0 : -1.0
                let click = Double.random(in: -1...1) * exp(-t * 420) * 0.5
                return (square * 0.16 + click * 0.5) * env * (0.30 + 0.30 * intensity)
            }
        case 2:
            return render(0.11) { t in
                let env = exp(-t * 24)
                let p = 66 + 34 * intensity
                let body = sin(2 * .pi * p * t) * 0.85 + sin(2 * .pi * p * 2.1 * t) * 0.12
                let thump = Double.random(in: -1...1) * exp(-t * 200) * 0.18
                return (body + thump) * env * (0.42 + 0.30 * intensity)
            }
        default:
            let pitch = 172 + 78 * intensity
            let amp = 0.30 + 0.34 * intensity
            return render(0.062) { t in
                let env = exp(-t * 40)
                let skin = Double.random(in: -1...1) * exp(-t * 170) * 0.8
                let body = sin(2 * .pi * pitch * t) * 0.5 + sin(2 * .pi * pitch * 1.86 * t) * 0.2
                return (skin + body) * env * amp
            }
        }
    }

    /// 落定轻响：一记短促的高音木鱼
    private func makeDing() -> AVAudioPCMBuffer? {
        render(0.55) { t in
            let env = exp(-t * 10)
            let tone = sin(2 * .pi * 1318.5 * t) + 0.32 * sin(2 * .pi * 2637 * t)
            let click = Double.random(in: -1...1) * exp(-t * 300) * 0.45
            return (tone * 0.32 + click * 0.35) * env
        }
    }

    /// 上扬音：0.5 秒扫频（220 → 1320Hz）叠一点噪声，只在抽取最后阶段响一次
    private func makeRiser() -> AVAudioPCMBuffer? {
        let dur = 0.5
        return render(dur) { t in
            let k = min(1, t / dur)
            let f = 220 * pow(6.0, k)            // 指数上扬，听感更"冲"
            let env = pow(k, 1.6) * (1 - pow(k, 6))   // 起得慢、收得急
            let tone = sin(2 * .pi * f * t) * 0.55
            let air = Double.random(in: -1...1) * 0.12
            return (tone + air) * env * 0.75
        }
    }

    // MARK: - 25 种落定音

    /// 音色配方表。所有音高用十二平均律的常用音，方便互相叠成和弦。
    private func makeTheme(_ theme: SoundTheme) -> AVAudioPCMBuffer? {
        switch theme {

        // ── 打击 ──────────────────────────────────────────

        case .bell:
            // C6 → G6 两记，非整数谐波给金属泛音
            return synth(1.9,
                         notes: [(0.00, 1046.50), (0.27, 1567.98)],
                         decay: 3.1,
                         harmonics: [(1, 0.50), (2, 0.22), (2.76, 0.13), (5.40, 0.05)],
                         amp: 0.62)

        case .marimba:
            // 三记木质短音，起音带敲击噪声
            return synth(1.5,
                         notes: [(0.00, 783.99), (0.115, 1046.50), (0.235, 1318.51)],
                         decay: 7.5,
                         harmonics: [(1, 0.55), (4.0, 0.16), (9.2, 0.05)],
                         noise: 0.35, noiseDecay: 320,
                         amp: 0.55)

        case .woodblock:
            // 清脆的一记木鱼
            return synth(0.32,
                         notes: [(0, 1180)],
                         decay: 42,
                         harmonics: [(1, 0.55), (2.4, 0.22), (3.7, 0.08)],
                         noise: 0.55, noiseDecay: 500,
                         amp: 0.62)

        case .tambourine:
            // 铃鼓：噪声串 + 高频金属群
            return synth(0.85,
                         notes: [(0, 3200), (0.02, 4180), (0.045, 5120)],
                         decay: 13,
                         harmonics: [(1, 0.16), (1.37, 0.12), (2.19, 0.07)],
                         noise: 0.55, noiseDecay: 26,
                         amp: 0.62)

        // ── 旋律 ──────────────────────────────────────────

        case .arpeggio:
            // C5-E5-G5-C6 四音上行
            return synth(2.0,
                         notes: [(0.00, 523.25), (0.075, 659.25), (0.150, 783.99), (0.235, 1046.50)],
                         decay: 2.6,
                         harmonics: [(1, 0.42), (2, 0.16), (3, 0.06)],
                         amp: 0.55)

        case .piano:
            // C 大三和弦，谐波丰富、衰减线性
            return synth(2.4,
                         notes: [(0.00, 261.63), (0.012, 329.63), (0.024, 392.00), (0.036, 523.25)],
                         decay: 2.2,
                         harmonics: [(1, 0.46), (2, 0.24), (3, 0.12), (4, 0.06), (5, 0.03)],
                         noise: 0.10, noiseDecay: 600,
                         amp: 0.52)

        case .musicbox:
            // 八音盒：高音小音阶，衰减快、泛音亮
            return synth(1.7,
                         notes: [(0.00, 880), (0.13, 1046.5), (0.26, 1318.51), (0.39, 1760)],
                         decay: 9,
                         harmonics: [(1, 0.40), (3.1, 0.13), (5.4, 0.05)],
                         amp: 0.50)

        case .harp:
            // 竖琴：8 音快速刮奏
            let scale: [Double] = [523.25, 587.33, 659.25, 783.99, 880, 1046.50, 1174.66, 1318.51]
            return synth(2.1,
                         notes: scale.enumerated().map { (Double($0.offset) * 0.045, $0.element) },
                         decay: 4.5,
                         harmonics: [(1, 0.40), (2, 0.14), (3, 0.05)],
                         amp: 0.50)

        case .vibraphone:
            // 电颤琴：三音 + 5Hz 颤音
            return synth(2.2,
                         notes: [(0.00, 783.99), (0.18, 1046.50), (0.36, 1318.51)],
                         decay: 3.4,
                         harmonics: [(1, 0.46), (4, 0.14)],
                         amp: 0.50,
                         vibrato: 5, vibratoRate: 5.5)

        case .guitar:
            // 吉他扫弦：6 根弦错开 12ms
            let strings: [Double] = [196.00, 246.94, 293.66, 392.00, 493.88, 587.33]
            return synth(1.8,
                         notes: strings.enumerated().map { (Double($0.offset) * 0.012, $0.element) },
                         decay: 5.5,
                         wave: .saw,
                         harmonics: [(1, 0.34), (2, 0.16), (3, 0.08)],
                         noise: 0.16, noiseDecay: 380,
                         amp: 0.46)

        case .brass:
            // 铜管三连：锯齿波 + 谐波堆叠
            return synth(1.8,
                         notes: [(0.00, 392.00), (0.15, 523.25), (0.30, 659.25)],
                         decay: 3.6,
                         wave: .saw,
                         harmonics: [(1, 0.34), (2, 0.20), (3, 0.12), (4, 0.06)],
                         amp: 0.44)

        case .horn:
            // 号角：更长的持音，方波，慢衰减
            return synth(2.2,
                         notes: [(0.00, 349.23), (0.10, 440.00), (0.20, 523.25)],
                         decay: 2.4,
                         wave: .square,
                         harmonics: [(1, 0.26), (2, 0.10), (3, 0.04)],
                         amp: 0.42)

        // ── 电子 ──────────────────────────────────────────

        case .whoosh:
            // 上扬扫频 + 收尾 ping
            let dur = 1.45
            return render(dur) { t in
                let k = min(1, t / 0.72)
                let sweepF = 180 * pow(9.0, k)
                let sweepEnv = pow(k, 1.4) * (1 - min(1, max(0, (t - 0.72) / 0.25)))
                let sweep = sin(2 * .pi * sweepF * t) * 0.40 + Double.random(in: -1...1) * 0.18
                var ping = 0.0
                let lt = t - 0.55
                if lt >= 0 {
                    ping = sin(2 * .pi * 1568 * lt) * exp(-lt * 6.5) * 0.30
                        + sin(2 * .pi * 3136 * lt) * exp(-lt * 11) * 0.10
                }
                return (sweep * sweepEnv * 0.7 + ping) * 0.85
            }

        case .laser:
            // 激光：2400Hz 急速下坠到 300Hz，方波增加"硬"
            return synth(0.5,
                         notes: [(0, 2400)],
                         decay: 7,
                         wave: .square,
                         harmonics: [(1, 0.34), (2, 0.10)],
                         glide: 0.125, glideTime: 0.35,
                         amp: 0.42)

        case .chiptune:
            // 像素游戏：方波三连音（E6-G6-C7）
            return synth(1.3,
                         notes: [(0.00, 1318.51), (0.09, 1567.98), (0.18, 2093.00)],
                         decay: 6,
                         wave: .square,
                         harmonics: [(1, 0.30), (3, 0.05)],
                         amp: 0.34)

        case .synthrise:
            // 合成上升：两把锯齿从低八度滑到目标音，再叠一个亮和弦
            return synth(1.6,
                         notes: [(0.00, 196.00), (0.10, 246.94), (0.20, 293.66),
                                 (0.55, 587.33), (0.55, 739.99), (0.55, 880.00)],
                         decay: 3.2,
                         wave: .saw,
                         harmonics: [(1, 0.30), (2, 0.14)],
                         glide: 2.0, glideTime: 0.45,
                         amp: 0.40)

        // ── 自然 ──────────────────────────────────────────

        case .waterdrop:
            // 水滴：短促高频向下滑
            return synth(0.7,
                         notes: [(0, 1740)],
                         decay: 16,
                         harmonics: [(1, 0.5), (2.1, 0.12)],
                         glide: 0.55, glideTime: 0.12,
                         amp: 0.52)

        case .bubble:
            // 气泡：三个上滑短音，像水底冒泡
            return synth(1.2,
                         notes: [(0.00, 420), (0.14, 560), (0.28, 720)],
                         decay: 9,
                         harmonics: [(1, 0.46), (2, 0.10)],
                         glide: 1.6, glideTime: 0.09,
                         amp: 0.46)

        case .windchime:
            // 风铃：5 记随机错开的高音，泛音非整数倍
            var chimes: [(Double, Double)] = []
            var cursor = 0.0
            for _ in 0..<5 {
                chimes.append((cursor, Double.random(in: 1100...2400)))
                cursor += Double.random(in: 0.06...0.17)
            }
            return synth(2.3,
                         notes: chimes,
                         decay: 4.2,
                         harmonics: [(1, 0.36), (2.4, 0.12), (3.9, 0.05)],
                         amp: 0.42)

        case .choir:
            // 人声：三角波 + 轻微颤音唱一个三和弦
            return synth(2.6,
                         notes: [(0.00, 392.00), (0.00, 493.88), (0.00, 587.33)],
                         decay: 1.1,
                         wave: .triangle,
                         harmonics: [(1, 0.28), (2, 0.10), (3, 0.05)],
                         amp: 0.42,
                         vibrato: 2.5, vibratoRate: 4.8)

        case .glass:
            // 玻璃：高音 + 极慢衰减，长泛音
            return synth(2.6,
                         notes: [(0, 1568.00)],
                         decay: 1.5,
                         harmonics: [(1, 0.42), (2.76, 0.16), (5.4, 0.07), (8.1, 0.03)],
                         amp: 0.40)

        // ── 趣味 ──────────────────────────────────────────

        case .applause:
            return makeApplause()

        case .heartbeat:
            // 心跳：两记低频，第二记弱一点
            return synth(1.0,
                         notes: [(0.00, 58), (0.28, 52)],
                         decay: 14,
                         harmonics: [(1, 0.85), (2.1, 0.16)],
                         amp: 0.62)

        case .boing:
            // 弹簧：频率抖着往下掉
            return render(0.65) { t in
                let k = min(1, t / 0.45)
                let base = 420 * pow(0.16, k)
                let wobble = 1 + 0.08 * sin(2 * .pi * 18 * t)
                let f = base * wobble
                let env = exp(-t * 5.5)
                return (sin(2 * .pi * f * t) * 0.52 + sin(2 * .pi * f * 2 * t) * 0.12) * env
            }

        case .pop:
            // 弹跳：短促的"啵"
            return synth(0.25,
                         notes: [(0, 1100)],
                         decay: 30,
                         harmonics: [(1, 0.55), (2, 0.10)],
                         glide: 0.35, glideTime: 0.06,
                         amp: 0.58)
        }
    }

    /// 掌声：一串随机分布的拍手脉冲 + 整体淡出。
    ///
    /// 不能用纯白噪声——那是"电视雪花"，不是掌声。每一下拍手是
    /// 「短噪声 + 一点 1.8kHz 的金属感」，几十下错开叠起来才有人群感。
    private func makeApplause() -> AVAudioPCMBuffer? {
        var hits: [Double] = []
        var t = 0.0
        while t < 2.05 {
            hits.append(t)
            t += Double.random(in: 0.030...0.070)
        }
        return render(2.2) { time in
            var sum = 0.0
            for h in hits {
                let lt = time - h
                guard lt >= 0, lt < 0.09 else { continue }
                let env = exp(-lt * 48)
                let body = Double.random(in: -1...1) * 0.55
                    + sin(2 * .pi * 1800 * lt) * 0.14
                sum += body * env
            }
            let tail = max(0, 1 - max(0, time - 1.55) / 0.65)
            return sum * 0.30 * tail
        }
    }

    // MARK: - 工具专属音色（3.3）
    //
    // 每个工具的过程音都从「这个工具在真实世界里发出什么声音」出发，
    // 而不是从「什么声音好听」出发。所以没有用统一的合成配方：
    //
    //   点名  = 木牌点在点名册上     → 极短、干的木质嗒
    //   数字  = 机械计数器           → 高频细嘀 + click
    //   骰子  = 塑料骰子滚过桌面     → 噪声 + 木质体，每次音高都不同
    //   硬币  = 金属被弹起还在空中转 → 非整数谐波 + 长一点点的衰减
    //   抽卡  = 洗牌                 → 带通噪声的「唰」
    //   颜色  = 取色器               → 很轻的正弦「嘟」
    //   字母  = 打字机               → 中频噪声 + 字锤
    //   猜拳  = 手往下挥             → 三拍「呼」，越挥越急
    //   是或否 = 悬念                → 心跳低音
    //   分组  = 洗牌分堆             → 一串错开的「唰」

    /// 过程音。`step` 0…1 是进度，`beat` 是本轮第几拍（用来做不规则变化）。
    ///
    /// 全部预生成成 8 档，运行时只是挑一个来播 —— 44.1kHz 现算会有几毫秒卡顿，
    /// 而这个过程音每 40ms 就要响一次。
    private func toolTick(_ tool: ToolSound, step: Double, beat: Int) -> AVAudioPCMBuffer? {
        let list = toolTicks[tool] ?? []
        guard !list.isEmpty else { return nil }
        // 骰子、硬币这类"实物"在滚动中不该是等间隔的标准音阶 ——
        // 每 3 拍抖一次档位，听起来才像东西在桌上乱撞。
        let jitter = tool.hasOwnSettle && beat % 3 == 1 ? 1 : 0
        let i = min(list.count - 1,
                    max(0, Int((step * Double(list.count - 1)).rounded()) + jitter))
        return list[i]
    }

    private func makeToolTick(_ tool: ToolSound, step: Double) -> AVAudioPCMBuffer? {
        let k = step

        switch tool {

        case .pick:
            // 木牌「嗒」。音高随进度微抬，但尾巴必须极短：
            // 二十几拍叠在一起时，长尾会糊成一片嗡嗡声，听不出"一拍一拍"。
            let f = 430 + 180 * k
            return render(0.070) { t in
                let env = exp(-t * 82)
                let body = sin(2 * .pi * f * t) * 0.55
                    + sin(2 * .pi * f * 2.41 * t) * 0.16
                let knock = Double.random(in: -1...1) * exp(-t * 540) * 0.50
                return (body + knock) * env * (0.40 + 0.30 * k)
            }

        case .number:
            // 机械计数器：很细、很干的一声「嘀」，几乎只有 click 和一点点音高。
            let f = 1500 + 900 * k
            return render(0.045) { t in
                let env = exp(-t * 120)
                let tone = sin(2 * .pi * f * t) * 0.30
                let click = Double.random(in: -1...1) * exp(-t * 700) * 0.45
                return (tone + click) * env * (0.36 + 0.26 * k)
            }

        case .dice:
            // 骰子滚过桌面：一个塑料壳的"咔"叠一点低频的"咯"，
            // 音高每次随机，才不像节拍器。
            let f = (150 + 70 * k) * Double.random(in: 0.86...1.18)
            return render(0.085) { t in
                let env = exp(-t * 62)
                let body = sin(2 * .pi * f * t) * 0.40
                    + sin(2 * .pi * f * 2.7 * t) * 0.14
                let shell = Double.random(in: -1...1) * exp(-t * 340) * 0.60
                return (body + shell) * env * (0.38 + 0.26 * k)
            }

        case .coin:
            // 硬币：金属的非整数谐波。这一拍是"还在空中转"，所以给一点点余韵。
            let f = (2200 + 700 * k) * Double.random(in: 0.97...1.04)
            return render(0.26) { t in
                let env = exp(-t * 17)
                let v = sin(2 * .pi * f * t) * 0.34
                    + sin(2 * .pi * f * 1.51 * t) * 0.16
                    + sin(2 * .pi * f * 2.27 * t) * 0.09
                let chink = Double.random(in: -1...1) * exp(-t * 260) * 0.35
                return (v + chink) * env * (0.34 + 0.22 * k)
            }

        case .card:
            // 洗牌「唰」：噪声被一个快速滑动的包络切开，像两张牌互相摩擦。
            let dur = 0.10 + 0.04 * k
            let center = 2600 + 1200 * k
            return render(dur) { t in
                let env = sin(.pi * min(1, t / dur))
                let n = Double.random(in: -1...1)
                // 用正弦乘噪声 = 简易带通，噪声不会刺耳
                let band = n * sin(2 * .pi * center * t)
                return band * env * 0.36
            }

        case .color:
            // 取色器：很轻的「嘟」，正弦为主，几乎不带噪声。
            let f = 660 + 260 * k
            return render(0.085) { t in
                let env = exp(-t * 26)
                let v = sin(2 * .pi * f * t) * 0.40
                    + sin(2 * .pi * f * 2 * t) * 0.08
                return v * env * (0.28 + 0.18 * k)
            }

        case .letter:
            // 打字机：字锤击纸的「嗒」，比点名更脆、更靠中频。
            let f = 780 + 240 * k
            return render(0.055) { t in
                let env = exp(-t * 105)
                let body = sin(2 * .pi * f * t) * 0.32
                let strike = Double.random(in: -1...1) * exp(-t * 620) * 0.62
                return (body + strike) * env * (0.40 + 0.24 * k)
            }

        case .rps:
            // 手往下挥的「呼」。猜拳是三拍：石头—剪刀—布，
            // 所以每一拍音高不同（do / mi / sol），第三拍最高，然后就出拳。
            let pitches: [Double] = [320, 400, 500]
            let f = pitches[step < 0.34 ? 0 : (step < 0.68 ? 1 : 2)]
            let dur = 0.13
            return render(dur) { t in
                let p = min(1, t / dur)
                let env = sin(.pi * p)
                let sweep = f * (0.85 + 0.3 * p)
                let tone = sin(2 * .pi * sweep * t) * 0.26
                let air = Double.random(in: -1...1) * 0.30 * p
                return (tone + air) * env * 0.34
            }

        case .yesNo:
            // 心跳：低频两下（lub-dub），越到后面越沉。
            let f = 54 + 22 * k
            return render(0.20) { t in
                let lub = sin(2 * .pi * f * t) * exp(-t * 26)
                let dub = sin(2 * .pi * f * 0.86 * max(0, t - 0.10) * t) * exp(-max(0, t - 0.10) * 30)
                return (lub * 0.55 + dub * 0.32) * 0.55
            }

        case .shuffle:
            // 洗牌分堆：比抽卡宽一点、软一点的「唰」。
            let dur = 0.13
            let center = 2000 + 1500 * k
            return render(dur) { t in
                let env = sin(.pi * min(1, t / dur))
                let band = Double.random(in: -1...1) * sin(2 * .pi * center * t)
                return band * env * 0.30
            }
        }
    }

    /// 落定音（只有 `hasOwnSettle` 的工具会调到这里）。
    private func makeToolSettle(_ tool: ToolSound) -> AVAudioPCMBuffer? {
        switch tool {

        case .dice:
            // 骰子砸在桌上：一记闷响，接两下越来越小的弹跳。
            let bounces = [0.085, 0.155, 0.205]
            return render(0.55) { t in
                var v = 0.0
                // 主落地
                let thump = sin(2 * .pi * (118 - 40 * min(1, t / 0.06)) * t) * exp(-t * 26)
                let shell = Double.random(in: -1...1) * exp(-t * 240) * 0.5
                v += (thump * 0.62 + shell * 0.45)
                // 弹跳
                for (i, b) in bounces.enumerated() where t >= b {
                    let lt = t - b
                    guard lt < 0.10 else { continue }
                    let a = 0.26 / Double(i + 1)
                    v += Double.random(in: -1...1) * exp(-lt * 300) * a
                        + sin(2 * .pi * 300 * lt) * exp(-lt * 60) * a * 0.5
                }
                return v * 0.52
            }

        case .coin:
            // 硬币落在桌面打转：金属高频 + 音高游移，越转越慢，0.9 秒收干。
            // 关键是那个 wobble —— 没有它就是一记"敲铁皮"，不像"在转"。
            return render(0.95) { t in
                let env = exp(-t * 3.2)
                let wobble = sin(2 * .pi * (10.0 - 5.5 * t) * t) * 30
                let f = 2480 + wobble
                let v = sin(2 * .pi * f * t) * 0.40
                    + sin(2 * .pi * f * 1.51 * t) * 0.20
                    + sin(2 * .pi * f * 2.27 * t) * 0.11
                let land = Double.random(in: -1...1) * exp(-t * 210) * 0.55
                return (v + land) * env * 0.44
            }

        case .card:
            // 发牌「啪」：纸边拍的瞬间，后面跟一点摩擦。
            return render(0.30) { t in
                let slap = Double.random(in: -1...1) * exp(-t * 90) * 0.62
                let body = sin(2 * .pi * 240 * t) * exp(-t * 42) * 0.18
                let slide = Double.random(in: -1...1) * sin(2 * .pi * 3400 * t) * exp(-max(0, t - 0.05) * 26) * 0.18
                return (slap + body + slide) * 0.62
            }

        case .rps:
            // 手掌相击：噪声爆发 + 一点身体的中频，最后收一记木头的"咚"。
            return render(0.38) { t in
                let clap = Double.random(in: -1...1) * exp(-t * 70) * 0.60
                let flesh = sin(2 * .pi * 190 * t) * exp(-t * 48) * 0.22
                let thud = sin(2 * .pi * 96 * max(0, t - 0.02)) * exp(-max(0, t - 0.02) * 30) * 0.20
                return (clap + flesh + thud) * 0.58
            }

        case .color:
            // 取色落定：两个干净的正弦叠成纯五度，短促、不抢戏。
            return synth(0.55,
                         notes: [(0, 880), (0.055, 1320)],
                         decay: 5.2,
                         harmonics: [(1, 0.50), (2, 0.10)],
                         amp: 0.46)

        case .pick, .number, .letter, .yesNo, .shuffle:
            return nil
        }
    }

    // MARK: - 预生成（第一次发声时才算，之后复用）

    private lazy var drums: [[AVAudioPCMBuffer]] = (0..<3).map { set in
        (0..<8).compactMap { i in makeDrum(Double(i) / 7, set: set) }
    }

    /// 每个工具的 8 档过程音。第一次用到某工具时合成一次（8 段不到 1MB），之后常驻。
    private lazy var toolTicks: [ToolSound: [AVAudioPCMBuffer]] = {
        var out: [ToolSound: [AVAudioPCMBuffer]] = [:]
        for tool in ToolSound.allCases {
            out[tool] = (0..<8).compactMap { i in
                makeToolTick(tool, step: Double(i) / 7)
                    .flatMap { Self.normalize($0, to: 0.52) }
            }
        }
        return out
    }()

    private var toolSettleCache: [ToolSound: AVAudioPCMBuffer] = [:]

    private func toolSettle(_ tool: ToolSound) -> AVAudioPCMBuffer? {
        if let cached = toolSettleCache[tool] { return cached }
        if let made = makeToolSettle(tool) {
            // 落地声的响度也要统一，否则"骰子轻、硬币响"会被当成 bug。
            toolSettleCache[tool] = Self.normalize(made, to: 0.64)
        }
        return toolSettleCache[tool]
    }

    private lazy var dingBuffer: AVAudioPCMBuffer? = makeDing()
    private lazy var riserBuffer: AVAudioPCMBuffer? = makeRiser()

    /// 每种风格的落定音只合成一次。第一次用到某风格时会有一次几毫秒的合成，
    /// 之后都走缓存（合成 2 秒 44.1kHz 单声道大约 88k 个采样，够快）。
    private var victoryCache: [SoundTheme: AVAudioPCMBuffer] = [:]

    private func victoryBuffer(for theme: SoundTheme) -> AVAudioPCMBuffer? {
        if let cached = victoryCache[theme] { return cached }
        // 合成出来的原始波形响度差得很远（激光 0.19 / 钢琴 1.00），
        // 不统一的话「随机音色」会变成「随机音量」，抽到小声的还以为没响。
        if let made = makeTheme(theme) {
            victoryCache[theme] = Self.normalize(made, to: 0.62)
        }
        return victoryCache[theme]
    }

    /// 把整段波形缩放到目标峰值，让所有音色听起来一样响。
    ///
    /// 只放大不压缩动态：短促的敲击本来峰均比就大，压过头会失去"脆"。
    /// 最多放大 4 倍 —— 否则极安静的素材（比如掌声尾巴）会被抬成一片嘶声。
    private static func normalize(_ buffer: AVAudioPCMBuffer, to target: Float) -> AVAudioPCMBuffer {
        guard let ch = buffer.floatChannelData?[0] else { return buffer }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return buffer }

        var peak: Float = 0
        for i in 0..<n { peak = max(peak, abs(ch[i])) }
        guard peak > 0.0001 else { return buffer }

        let gain = min(4, target / peak)
        guard abs(gain - 1) > 0.01 else { return buffer }
        for i in 0..<n { ch[i] = max(-1, min(1, ch[i] * gain)) }
        return buffer
    }

    deinit { previewTimer?.invalidate() }
}
