import Foundation

// MARK: - 班级数据模型
//
// Random **不再内置任何真实名单**。
//
// 以前把 2601–2606 六个班 294 个姓名直接编译进应用，那种做法有两个问题：
//   1. 应用里带着别人的学生姓名，不能分发给其他老师；
//   2. 打开就有别人的班，用不上也删不掉。
// 所以现在首次使用必须导入自己的 .randomroster 名单文件（设置页 / 拖进窗口 / 双击文件），
// 导入后会自动记住，下次打开直接用。
//
// 这里只定义「一个班」的形状，数据全部来自导入：
//   · id —— 班号，同时是名单内唯一键（"2601"、"初一3班"、"A 组" 都行）
//   · names —— 姓名表，下标 0 对应 1 号

enum ClassRoster {

    /// 年级。
    ///
    /// 班号前两位就是入学年（"2401" = 2024 年入学）。用「当前学年 − 入学年 + 1」
    /// 反推年级，而不是把 24→初三 写死 —— 明年这批人升高中，同一个 2401
    /// 就不该再显示成初三了。九月一过自动换档。
    enum Grade: Int, CaseIterable, Identifiable, Comparable {
        case junior1 = 1, junior2 = 2, junior3 = 3

        var id: Int { rawValue }
        var title: String {
            switch self {
            case .junior1: return "初一"
            case .junior2: return "初二"
            case .junior3: return "初三"
            }
        }
        /// 侧边栏分组标题：写成「初三年级」，与「2401 班」区分开。
        var groupTitle: String {
            switch self {
            case .junior1: return "初一年级"
            case .junior2: return "初二年级"
            case .junior3: return "初三年级"
            }
        }
        static func < (a: Grade, b: Grade) -> Bool { a.rawValue < b.rawValue }
    }

    /// 当前学年的起始年份（9 月 1 日换学年）。
    static func schoolYearStart(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month], from: now)
        let year = c.year ?? 2000
        return (c.month ?? 1) >= 8 ? year : year - 1
    }

    /// 从班号推年级。"2401" → 初三（2026 学年时）。推不出来就返回 nil（归入「其他」）。
    static func grade(forClassID id: String, schoolYearStart: Int = schoolYearStart()) -> Grade? {
        let digits = id.prefix(2)
        guard digits.count == 2, let yy = Int(digits) else { return nil }
        let enrolled = 2000 + yy
        let lv = schoolYearStart - enrolled + 1
        return Grade(rawValue: lv)
    }

    struct SchoolClass: Identifiable, Hashable {
        let id: String          // "2601"
        let names: [String]     // 下标 0 → 1 号
        var titleOverride: String? = nil   // 外部名单可自定义显示名

        var count: Int { names.count }

        var title: String {
            if let t = titleOverride, !t.trimmingCharacters(in: .whitespaces).isEmpty {
                return t
            }
            return "\(id) 班"
        }

        var shortTitle: String {
            if let t = titleOverride, !t.trimmingCharacters(in: .whitespaces).isEmpty {
                return t
            }
            return id
        }

        /// 所在年级。班号不是「两位年份 + 序号」形式的外部名单会得到 nil。
        var grade: ClassRoster.Grade? {
            ClassRoster.grade(forClassID: id)
        }
    }

    /// 空名单——尚未导入任何班级时的初始状态。
    static let empty: [SchoolClass] = []
}
