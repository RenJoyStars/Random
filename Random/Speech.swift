import AVFoundation
import Foundation
import Observation

/// 点名后的语音朗读。
///
/// ⚠️ 概念澄清：这**不是**「调用 VoiceOver」—— VoiceOver 是屏幕阅读器，
/// 没有「念任意一段文本」的 API。这里用的是系统 TTS 引擎 `AVSpeechSynthesizer`，
/// 它和 VoiceOver 共用同一套语音库，所以你在系统设置里下载的语音
/// （婷婷、以及 Eddy/Flo 那批）这里都能选到。
///
/// 好处：**免权限、免联网、完全离线**。
///
/// 关于「为什么不如 VoiceOver 自然」：苹果的语音分四大档 ——
/// compact（预装，机械）/ enhanced（增强，~100MB）/ premium（优质，~300MB）/ Siri 音色。
/// 后几档都要用户去「系统设置 → 辅助功能 → 朗读内容 → 声音」手动下载，
/// 只下载过紧凑档时用哪个都一样机械。
///
/// ── Siri 音色：结论是「用不了」（2026-09-28 实测，两个平台各测一遍）──
///
/// 磁盘上确实躺着 Siri 的中文音色（`/System/Library/SpeechBase/Voices/Li-MuCompact.SpeechVoice`，
/// 官方名叫「李慕」；同目录另有「语舒」），macOS 上它的 identifier 是
/// `com.apple.siri.natural.Li-Mu`。但**列不列得出来，取决于跑代码的进程是谁**：
///
/// | 进程形态 | 语音总数 | 中文 | Siri 音色 |
/// |---|---|---|---|
/// | Apple 自家签名（`swift` 解释器 / `osascript`） | 190 | 24 | **1**，且能合成 48kHz 神经音频 |
/// | 本 App（adhoc 签名 / Apple Development 证书签名 / 裸二进制） | 181 | 19 | **0** |
///
/// 一句话：系统把 Siri 音色**只放行给 Apple 自家签名的二进制**。
/// 曾经怀疑是签名档位问题，用本机那张 Apple Development 证书重签一遍 —— 照样 0。
/// `say -v Li-Mu` 也不行：实测它的输出与「婷婷」逐字节相同，是**悄悄回退**，不是真在用。
/// iOS 那边更彻底：模拟器上 Siri 音色数量为 0，按 identifier 创建直接返回 nil。
///
/// 所以想让朗读更自然，**唯一走得通的路**是去系统设置里下载「增强 / 优质」档语音
/// （本 App 会把它们自动排到最前并优先选中）。下面这套 Siri 识别逻辑留着是**防御性**的：
/// 万一哪天苹果放行，直接就能用、不用改代码；放行之前它永远匹配不到任何东西。
/// 需要「很像人」的效果，还可以考虑系统自带的「个人声音」（要本人照稿录一批句子，属另一条路）。
/// 另外提供了「跟随系统朗读设置」（prefersAssistiveTechnologySettings），
/// 直接用系统里那套配置，和 VoiceOver 用的是同一份。
///
/// 设计取舍（按老师的要求）：
/// - 只念点名结果，且**直接念名字**，不加任何客套前后缀；
/// - 只在点名落定时开口，其他工具不朗读（避免课堂上一路念个不停）。
@Observable
final class Speech {

    static let shared = Speech()

    // MARK: - 设置
    //
    // ⚠️ 这几个必须是**存储属性 + didSet 持久化**，不能写成"读写 UserDefaults 的计算属性"：
    // 计算属性不产生观察事件，设置页拖动语速滑条时值虽然写进去了，
    // 但 SwiftUI 收不到通知 → 滑块和数字都纹丝不动（踩过）。
    // 标成 @Observable 之后，改值 → 界面自动刷新。

    /// 点名后是否读出姓名
    var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "speech.enabled") }
    }

    /// 语速（0.3 慢 ~ 0.6 快）。
    /// 系统默认是 0.5，念姓名这种短词会显得赶，所以默认稍慢一点。
    var rate: Double {
        didSet { UserDefaults.standard.set(rate, forKey: "speech.rate") }
    }

    /// 选中的语音 identifier；空 = 自动挑一个中文语音
    var voiceIdentifier: String? {
        didSet { UserDefaults.standard.set(voiceIdentifier, forKey: "speech.voice") }
    }

    /// 跟随系统「朗读内容」里的语音与语速。
    ///
    /// 这就是「用 VoiceOver 那套声音」的正规做法：`prefersAssistiveTechnologySettings = true`
    /// 会让系统拿它自己配置的语音/语速来念，而不是我们指定的默认档语音。
    /// 开着的另一个好处是：用户在系统里把语速调成自己习惯的，这里自动跟着走。
    var followsSystemVoice: Bool {
        didSet { UserDefaults.standard.set(followsSystemVoice, forKey: "speech.followSystem") }
    }

    @ObservationIgnored private let synth = AVSpeechSynthesizer()

    /// init 里的赋值**不会**触发 didSet，所以这里直接读出来即可
    private init() {
        let d = UserDefaults.standard
        enabled = d.object(forKey: "speech.enabled") as? Bool ?? true
        rate = (d.object(forKey: "speech.rate") as? Double) ?? 0.45
        voiceIdentifier = d.string(forKey: "speech.voice")
        followsSystemVoice = d.object(forKey: "speech.followSystem") as? Bool ?? true
    }

    // MARK: - 可用语音

    /// 系统里的中文语音缓存。
    ///
    /// ⚠️ 不能写成 `static let` 一次性算完 —— 我们在设置页里明确叫用户
    /// 「去系统设置下载增强/优质语音，下载后这里就能选到」，
    /// 而语音是 App 运行期间才会出现在系统里的：缓存住就得**重启 App 才看得到**，
    /// 等于自己的提示在骗人。所以改成可失效的缓存 + 手动/自动重扫。
    private static var voiceCache: [AVSpeechSynthesisVoice]?

    /// 缓存失效计数：让界面知道"该重新拉列表了"。
    /// `@Observable` 只认实例属性，改这个值会触发设置页重绘。
    private(set) var voiceListVersion = 0

    /// 重新向系统要一遍语音列表（刚下载完语音回来时用）。
    static func refreshVoices() { voiceCache = nil }

    /// 实例版重扫：清缓存 + 通知界面重绘。
    func rescanVoices() {
        Self.voiceCache = nil
        voiceListVersion &+= 1
    }

    /// 系统里的中文语音（设置页给用户挑）。
    /// 列举语音要问系统，不必每次刷新界面都做一遍，所以缓存；
    /// 但用户下载完新语音后可以 `rescanVoices()` 让它立刻生效。
    static func chineseVoices() -> [AVSpeechSynthesisVoice] {
        if let cached = voiceCache { return cached }
        let list = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("zh") }
            .sorted(by: preferred)
        voiceCache = list
        return list
    }

    /// 界面用：读它会自动跟着 `rescanVoices()` 一起刷新。
    var voices: [AVSpeechSynthesisVoice] {
        _ = voiceListVersion
        return Self.chineseVoices()
    }

    /// 语音档位（给人看的）。
    ///
    /// ⚠️ 这是「听起来自不自然」的关键：系统预装的多是 `default`（紧凑档，拼接感明显），
    /// 而 `enhanced`（增强）/ `premium`（优质）要用户去
    /// 「系统设置 → 辅助功能 → 朗读内容 → 声音」里手动下载。
    /// 下载过之后这里就能选到 —— 音质差别非常明显。
    static func qualityLabel(_ v: AVSpeechSynthesisVoice) -> String {
        if isSiriVoice(v) { return "Siri 音色" }
        switch v.quality {
        case .premium:  return "优质"
        case .enhanced: return "增强"
        default:        return "紧凑"
        }
    }

    /// 档位数值：4 Siri 音色 / 3 优质 / 2 增强 / 1 紧凑。
    /// 自测用它验证"列表按质量降序"，省得测试文件还得 import AVFoundation。
    static func qualityRank(_ v: AVSpeechSynthesisVoice) -> Int {
        // Siri 音色在系统里被标成 enhanced 档，光看 quality 与普通增强档分不开，
        // 只能认 identifier 前缀，所以要先判它。
        if isSiriVoice(v) { return 4 }
        switch v.quality {
        case .premium:  return 3
        case .enhanced: return 2
        default:        return 1
        }
    }

    /// Siri 音色的 identifier 前缀。
    /// ⚠️ 第三方 App 正常**列不出来**（见文件顶部的实测表格），这里只是防御性识别。
    static let siriIdentifierPrefix = "com.apple.siri.natural."

    /// 是不是 Siri 音色。
    static func isSiriVoice(_ v: AVSpeechSynthesisVoice) -> Bool {
        v.identifier.hasPrefix(siriIdentifierPrefix)
    }

    /// 纯函数版：从 identifier 抠出可读名；不是 Siri 音色就返回 nil。
    /// （拆出来是为了让自测能直接验，不用真去凑一个 AVSpeechSynthesisVoice 实例。）
    static func siriDisplayName(forIdentifier id: String) -> String? {
        guard id.hasPrefix(siriIdentifierPrefix) else { return nil }
        let raw = String(id.dropFirst(siriIdentifierPrefix.count))
        return "Siri · \(siriChineseNames[raw] ?? raw)"
    }

    /// 界面上显示的名字。
    /// 系统给 Siri 音色的 name 是「声音1」「声音2」这种占位符，摆进列表里看不出是谁，
    /// 所以换成「Siri · 李慕」。
    static func displayName(_ v: AVSpeechSynthesisVoice) -> String {
        siriDisplayName(forIdentifier: v.identifier) ?? v.name
    }

    /// 中文 Siri 音色的官方译名（就是 Siri 设置里那两个「声音1 / 声音2」）。
    /// 名字取自系统语音资产目录：Li-MuCompact.SpeechVoice / Yu-ShuCompact.SpeechVoice。
    private static let siriChineseNames: [String: String] = [
        "Li-Mu": "李慕",
        "Yu-Shu": "语舒"
    ]

    /// 本机可用的 Siri 音色。
    /// ⚠️ 对第三方 App 而言**正常永远是 0 个**（系统只放行 Apple 自家进程）；
    /// 留着这个访问器是为了自测能据实报告、以及万一将来放行时不用改结构。
    static var siriVoices: [AVSpeechSynthesisVoice] {
        chineseVoices().filter { isSiriVoice($0) }
    }

    /// 挑语音的优先顺序：**档位高的在前**（这是音质的大头），
    /// 同档再优先 zh-CN、再优先「婷婷」（标准普通话音色），最后按名字排。
    /// 于是 Mac 上如果有 Siri 音色，它会自动排第一、并被 `resolvedVoice()` 自动选中。
    static func preferred(_ a: AVSpeechSynthesisVoice, _ b: AVSpeechSynthesisVoice) -> Bool {
        let (qa, qb) = (qualityRank(a), qualityRank(b))
        if qa != qb { return qa > qb }
        let (ca, cb) = (a.language == "zh-CN", b.language == "zh-CN")
        if ca != cb { return ca }
        let (ta, tb) = (a.identifier.contains("Tingting"), b.identifier.contains("Tingting"))
        if ta != tb { return ta }
        return (a.language, a.name) < (b.language, b.name)
    }

    /// 系统里有没有比预装更好的语音（用来在设置页提醒用户去下载）
    static var hasHighQualityVoice: Bool {
        // Siri 音色在系统里是 enhanced 档，本来就满足后半句；这里显式写出来是为了语义清楚。
        chineseVoices().contains { isSiriVoice($0) || $0.quality != .default }
    }

    /// 实际使用的语音：用户选过就用它，否则自动挑**当前质量最高**的那个中文语音。
    func resolvedVoice() -> AVSpeechSynthesisVoice? {
        if let id = voiceIdentifier, let v = AVSpeechSynthesisVoice(identifier: id) { return v }
        return Self.chineseVoices().first
    }

    /// 设置页显示用：现在到底会用哪个语音念。
    /// 「为什么听着还是不自然」这个问题，看一眼这行就有答案 —— 大概率是只装了紧凑档。
    var currentVoiceDescription: String {
        if followsSystemVoice { return "跟随系统朗读设置（与 VoiceOver 同一套）" }
        guard let v = resolvedVoice() else { return "系统里没有中文语音" }
        return "\(Self.displayName(v)) · \(Self.qualityLabel(v))"
    }

    // MARK: - 朗读

    /// 命令行自测进程没有 bundle identifier，直接跳过。
    /// （自测也不该真的发出声音。）
    private var hasBundle: Bool { Bundle.main.bundleIdentifier != nil }

    /// 要念的话：**直接念名字**（多人用顿号连起来）。纯函数，便于自测。
    static func announcement(for names: [String]) -> String {
        names.filter { !$0.isEmpty }.joined(separator: "、")
    }

    /// 朗读点名结果
    func announce(_ names: [String]) {
        let text = Self.announcement(for: names)
        guard !text.isEmpty else { return }
        speak(text)
    }

    func speak(_ text: String) {
        guard enabled, hasBundle, !text.isEmpty else { return }
        let u = AVSpeechUtterance(string: text)
        if followsSystemVoice {
            // 让系统拿它「朗读内容」里配置的语音和语速来念 —— 和 VoiceOver 用同一套。
            // 这时**不要**再设 voice/rate，否则会覆盖掉用户自己的设置。
            u.prefersAssistiveTechnologySettings = true
        } else {
            u.voice = resolvedVoice()
            u.rate = Float(rate)
        }
        synth.speak(u)
    }

}
