import Foundation

// MARK: - 随机分组（2.0）
//
// 音乐课上真正的用法不是「抽一个人」，是「分成 4 组做节奏合奏」「6 人一组做创编」。
// 这里只放纯算法，界面在 ToolViews.swift、状态在 AppModel.swift。
//
// 为什么要「洗牌后轮流发牌」而不是「切段」：
//   切段会让人数分配很偏（50 人分 4 组 → 13/13/13/11），
//   轮流发牌则是 13/13/12/12，最多差 1 人，分组时不会出现「这组多两个人」。

enum GroupMode: String, CaseIterable, Identifiable, Sendable {
    case byGroups   // 指定组数，人数自动均分
    case bySize     // 指定每组人数，组数自动算

    var id: String { rawValue }

    var title: String {
        switch self {
        case .byGroups: return "按组数"
        case .bySize:   return "按人数"
        }
    }

    var unit: String {
        switch self {
        case .byGroups: return "组"
        case .bySize:   return "人"
        }
    }
}

enum GroupSplit {

    /// 组数 / 每组人数的合法区间（界面输入框共用）
    static let groupRange = 2...12
    static let sizeRange  = 2...20

    /// 按组数分：洗牌后轮流发牌，各组人数最多差 1。
    static func byCount(_ pool: [Int], groups: Int) -> [[Int]] {
        guard groups > 0, !pool.isEmpty else { return [] }
        let n = min(groups, pool.count)
        let dealt = pool.shuffled()
        var out = Array(repeating: [Int](), count: n)
        for (i, value) in dealt.enumerated() { out[i % n].append(value) }
        return out.map { $0.sorted() }
    }

    /// 按每组人数分：组数 = ⌈总人数 / 每组人数⌉。
    ///
    /// 各组人数仍按轮流发牌，所以最多差 1 人；总人数不是整数倍时，
    /// 末尾几组会少一个人，而**不会**出现「最后一组只剩 1 个」这种极端情况
    /// （除非总人数本身就少到只够两组）。
    static func bySize(_ pool: [Int], size: Int) -> [[Int]] {
        guard size > 0, !pool.isEmpty else { return [] }
        let groups = Int((Double(pool.count) / Double(size)).rounded(.up))
        return byCount(pool, groups: max(1, groups))
    }

    /// 各组人数的摘要：「13、13、12、12」
    static func sizeSummary(_ groups: [[Int]]) -> String {
        groups.map { String($0.count) }.joined(separator: "、")
    }

    /// 复制 / 贴到黑板上的多行文本。
    static func plainText(_ groups: [[Int]],
                          names: (Int) -> String?,
                          showNumbers: Bool,
                          formatNo: (Int) -> String) -> String {
        groups.enumerated().map { index, members in
            let body = members.map { no -> String in
                let name = names(no) ?? "? 号"
                return showNumbers ? "\(formatNo(no)) \(name)" : name
            }.joined(separator: "  ")
            return "第 \(index + 1) 组（\(members.count) 人）：\(body)"
        }.joined(separator: "\n")
    }
}
