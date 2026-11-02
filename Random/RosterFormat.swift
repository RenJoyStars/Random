import Foundation

// MARK: - 规范名单格式（.randomroster）
//
// 这是 Random 读取「外部名单」用的标准格式，可分享给其他老师。
// 由 random-roster-import skill 把任意 Excel 自动转换而来，再由本 app 读取。
//
// 设计要点：
// - 纯 JSON，UTF-8，人可直接读写、便于排查。
// - 学生既可以是字符串（仅姓名），也可以是对象（带可选学号 no）。
//   不写学号时，Random 内部按 1、2、3… 顺序补。
// - 校验集中在 validate()，任何不合规都抛出带中文说明的错误。

struct RosterFormat: Codable {
    var name: String?
    var classes: [RosterClassEntry]
}

struct RosterClassEntry: Codable {
    var id: String
    var title: String?
    var students: [RosterStudentEntry]
}

/// 单个学生：字符串（仅姓名）或对象（姓名 + 可选学号）。
enum RosterStudentEntry: Codable {
    case name(String)
    case record(name: String, no: Int?)

    var nameValue: String {
        switch self {
        case .name(let s): return s
        case .record(let n, _): return n
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            self = .name(s)
            return
        }
        let obj = try c.decode(StudentObject.self)
        self = .record(name: obj.name, no: obj.no)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .name(let s):
            try c.encode(s)
        case .record(let n, let no):
            try c.encode(StudentObject(name: n, no: no))
        }
    }

    private struct StudentObject: Codable {
        var name: String
        var no: Int?
    }
}

enum RosterError: LocalizedError {
    case emptyClasses
    case emptyClassID
    case duplicateClassID(String)
    case emptyStudents(String)
    case emptyName(String)
    case duplicateStudentNo(String, Int)
    case invalidStudentNo(String, Int)
    case studentNoNotContiguous(String, missing: [Int])

    var errorDescription: String? {
        switch self {
        case .emptyClasses:        return "名单里至少要有一个班级"
        case .emptyClassID:        return "有班级的编号（id）为空"
        case .duplicateClassID(let id): return "班级编号重复：\(id)"
        case .emptyStudents(let id):   return "班级 \(id) 没有学生"
        case .emptyName(let id):       return "班级 \(id) 里有空白的姓名"
        case .duplicateStudentNo(let id, let no):
            return "班级 \(id) 里有重复的学号 \(no)，一个学号只能对应一个人"
        case .invalidStudentNo(let id, let no):
            return "班级 \(id) 里学号 \(no) 不合法，学号必须从 1 开始"
        case .studentNoNotContiguous(let id, let missing):
            let list = missing.prefix(10).map(String.init).joined(separator: "、")
            let more = missing.count > 10 ? " 等 \(missing.count) 个" : ""
            return "班级 \(id) 的学号不连续，缺 \(list)\(more)。"
                + "学号必须从 1 开始编号，中途不能跳号"
        }
    }
}

extension RosterFormat {

    /// 从文件 / 数据解析并校验。
    static func parse(_ data: Data) throws -> RosterFormat {
        let fmt = try JSONDecoder().decode(RosterFormat.self, from: data)
        try fmt.validate()
        return fmt
    }

    static func parse(url: URL) throws -> RosterFormat {
        let data = try Data(contentsOf: url)
        return try parse(data)
    }

    /// 规范校验：非空、班级 id 唯一、每班至少一人、姓名不能空白。
    func validate() throws {
        guard !classes.isEmpty else { throw RosterError.emptyClasses }
        var seen = Set<String>()
        for c in classes {
            let id = c.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else { throw RosterError.emptyClassID }
            guard !seen.contains(id) else { throw RosterError.duplicateClassID(id) }
            seen.insert(id)
            guard !c.students.isEmpty else { throw RosterError.emptyStudents(id) }
            for s in c.students {
                guard !s.nameValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw RosterError.emptyName(id)
                }
            }

            // 学号校验：全班都写了学号时才检查（部分写学号时按文件顺序，不参与校验）
            let numbers: [Int] = c.students.compactMap { s in
                if case .record(_, let no) = s { return no }
                return nil
            }
            guard numbers.count == c.students.count else { continue }
            guard numbers.allSatisfy({ $0 >= 1 }) else {
                let bad = numbers.filter { $0 < 1 }.min() ?? 0
                throw RosterError.invalidStudentNo(id, bad)
            }
            var seenNo = Set<Int>()
            for n in numbers {
                guard seenNo.insert(n).inserted else {
                    throw RosterError.duplicateStudentNo(id, n)
                }
            }
            // app 内部是「下标 i → i+1 号」，所以学号必须是 1…人数 的连续编号，
            // 中间跳号就没法用下标表示了 —— 与其悄悄错位，不如导入时直接说清楚。
            let expected = Set(1...c.students.count)
            let missing = expected.subtracting(seenNo).sorted()
            if !missing.isEmpty {
                throw RosterError.studentNoNotContiguous(id, missing: missing)
            }
        }
    }

    /// 转成 app 内部用的班级列表（去首尾空白）。
    ///
    /// ⚠️ 这里必须处理 `no`（学号）：app 内部的模型是「数组下标 i → i+1 号」，
    /// 名单里如果写的是 `{"name":"张三","no":12}` 却按文件顺序平铺，学号就会错位。
    /// 所以当**全班每个人都写了学号**时，先按学号升序排好再落地，
    /// 排完之后下标 i 就真的等于「第 i+1 号」，和 app 的假设对齐。
    /// 只要有一人没写学号，就退回文件顺序（此时文件顺序本身就是学号顺序）。
    func toSchoolClasses() -> [ClassRoster.SchoolClass] {
        classes.map { entry in
            let id = entry.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let allNumbered = entry.students.allSatisfy { s in
                if case .record(_, let no) = s { return no != nil }
                return false
            }
            let ordered: [RosterStudentEntry]
            if allNumbered {
                ordered = entry.students.sorted { a, b in
                    func no(_ s: RosterStudentEntry) -> Int {
                        if case .record(_, let n) = s { return n ?? Int.max }
                        return Int.max
                    }
                    return no(a) < no(b)
                }
            } else {
                ordered = entry.students
            }
            let names = ordered.map {
                $0.nameValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ClassRoster.SchoolClass(id: id, names: names, titleOverride: entry.title)
        }
    }

    /// 美化输出（写入文件用）。
    func prettyJSON() throws -> Data {
        try JSONEncoder().with {
            $0.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        }.encode(self)
    }
}

extension JSONEncoder {
    /// 链式设置。
    func with(_ configure: (JSONEncoder) -> Void) -> JSONEncoder {
        configure(self)
        return self
    }
}
