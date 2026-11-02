import Foundation

// MARK: - 历史记录（2.0）
//
// 一条时间线，装下点名、分组和八个随机工具的结果。两个用途：
//   1. 课上翻「刚才点的是谁」；
//   2. 课后导出 CSV，给班主任 / 教研组留个痕。
//
// 为什么点名要单独存 `numbers`：
//   班级页的「被点得最少」统计靠它。只看当前这轮的「已抽记录」是不够的 ——
//   那一轮一清空，谁被点过几次就全忘了，而这恰恰是「有没有总点那几个人」的证据。
//
// ⚠️ 历史只从 2.0 开始记。升级前抽过的人不会凭空补进来（没有时间戳，
//    补了就是编数据），界面上要如实说明这一点。

struct HistoryEntry: Codable, Hashable, Identifiable {
    var id: UUID
    var date: Date
    /// `pick`（点名）/ `group`（分组）/ 其余为 `Tool.rawValue`
    var kind: String
    /// 点名与分组记下班级 id，其他工具为空
    var classID: String
    /// 只有点名存学号（用于次数统计；分组不记，避免把分组也算成「被点」）
    var numbers: [Int]
    /// 给人看的结果文本
    var text: String

    init(id: UUID = UUID(), date: Date = Date(), kind: String,
         classID: String = "", numbers: [Int] = [], text: String) {
        self.id = id
        self.date = date
        self.kind = kind
        self.classID = classID
        self.numbers = numbers
        self.text = text
    }

    var isPick: Bool { kind == HistoryKind.pick }
}

enum HistoryKind {
    static let pick  = "pick"
    static let group = "group"

    /// 界面与 CSV 共用的中文名。
    ///
    /// 不认识的 kind 原样返回 —— 旧数据 / 手工改坏的 JSON 也不该让界面空着。
    static func title(_ kind: String) -> String {
        switch kind {
        case pick:  return "点名"
        case group: return "分组"
        default:    return Tool(rawValue: kind)?.title ?? kind
        }
    }

    static func symbol(_ kind: String) -> String {
        switch kind {
        case pick:  return "megaphone.fill"
        case group: return "person.3.sequence.fill"
        default:    return Tool(rawValue: kind)?.symbol ?? "questionmark.circle"
        }
    }
}

/// 「被点次数」的一行。班级统计里用。
struct PickStatEntry: Hashable, Identifiable {
    let no: Int
    let name: String
    let count: Int
    var id: Int { no }
}

// MARK: - CSV

enum HistoryCSV {

    static let header = "时间,类型,班级,结果"

    /// 一个字段的转义：
    /// 含逗号 / 引号 / 换行时用双引号包起来，内部的引号翻倍 —— Excel 与 Numbers 都认。
    static func escape(_ field: String) -> String {
        let needsQuote = field.contains(",") || field.contains("\"")
            || field.contains("\n") || field.contains("\r")
        guard needsQuote else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func timeText(_ date: Date, formatter: DateFormatter) -> String {
        formatter.string(from: date)
    }

    /// 生成整份 CSV。
    ///
    /// - 行序与界面一致（新的在上），方便一眼对上；
    /// - 开头带 **UTF-8 BOM**：不带的话 Excel 会把中文读成乱码，这是最常见的一句抱怨；
    /// - 换行用 CRLF：Excel for Mac 对纯 LF 的兼容性时好时坏。
    static func make(_ entries: [HistoryEntry],
                     classTitle: (String) -> String,
                     kindTitle: (String) -> String = HistoryKind.title) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var lines = [header]
        lines.reserveCapacity(entries.count + 1)
        for e in entries {
            let row = [
                escape(df.string(from: e.date)),
                escape(kindTitle(e.kind)),
                escape(e.classID.isEmpty ? "" : classTitle(e.classID)),
                escape(e.text),
            ]
            lines.append(row.joined(separator: ","))
        }
        return "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
    }
}
