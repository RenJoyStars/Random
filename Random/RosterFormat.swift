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

    var errorDescription: String? {
        switch self {
        case .emptyClasses:        return "名单里至少要有一个班级"
        case .emptyClassID:        return "有班级的编号（id）为空"
        case .duplicateClassID(let id): return "班级编号重复：\(id)"
        case .emptyStudents(let id):   return "班级 \(id) 没有学生"
        case .emptyName(let id):       return "班级 \(id) 里有空白的姓名"
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
        }
    }

    /// 转成 app 内部用的班级列表（去首尾空白）。
    func toSchoolClasses() -> [ClassRoster.SchoolClass] {
        classes.map { entry in
            let id = entry.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let names = entry.students.map {
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
