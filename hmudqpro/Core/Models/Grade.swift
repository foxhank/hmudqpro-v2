import Foundation

/// 课程成绩（教务 xskccjxx!getDataList.action 返回的 rows）。
struct GradeRecord: Identifiable, Equatable {
    var id: String { "\(xnxqmc)|\(kcmc)|\(zcj)|\(jxbmc)" }
    let xnxqmc: String   // 学年学期名称
    let kcmc: String     // 课程名
    let zcj: String      // 总成绩
    let cjfsmc: String   // 成绩方式（百分制/二级制）
    let xf: String       // 学分
    let cjjd: String     // 成绩绩点
    let kcdlmc: String   // 课程大类
    let kcflmc: String   // 课程分类
    let jxbmc: String    // 教学班
    let teaxms: String   // 教师
    let kkbmmc: String   // 开课部门
    let ksxzmc: String   // 考试性质
    let cjbzmc: String   // 成绩标志
    let bz: String       // 备注

    /// 是否通过：百分制 ≥60；二级制「通过/合格」；其余（缺考等特殊标记）视为未过。
    var isPassed: Bool {
        switch cjfsmc {
        case "百分制": return (Int(zcj) ?? 0) >= 60
        case "二级制": return zcj == "通过" || zcj == "合格"
        default: return !(zcj.isEmpty || zcj == "缺考" || zcj == "违纪")
        }
    }

    static func parse(_ json: String) throws -> [GradeRecord] {
        guard let data = json.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = obj["rows"] as? [[String: Any]] else {
            throw ParseError.notJSON
        }
        func s(_ row: [String: Any], _ k: String) -> String { (row[k] as? String) ?? "" }
        return rows.map {
            GradeRecord(xnxqmc: s($0, "xnxqmc"), kcmc: s($0, "kcmc"), zcj: s($0, "zcj"),
                        cjfsmc: s($0, "cjfsmc"), xf: s($0, "xf"), cjjd: s($0, "cjjd"),
                        kcdlmc: s($0, "kcdlmc"), kcflmc: s($0, "kcflmc"), jxbmc: s($0, "jxbmc"),
                        teaxms: s($0, "teaxms"), kkbmmc: s($0, "kkbmmc"), ksxzmc: s($0, "ksxzmc"),
                        cjbzmc: s($0, "cjbzmc"), bz: s($0, "bz"))
        }
    }

    enum ParseError: Error { case notJSON }
}

/// 等级考试成绩（四六级等，xskjcjxx!getDataList.action）。
struct ExamGradeRecord: Identifiable, Equatable {
    var id: String { "\(xnxqmc)|\(kjkcmc)|\(kssj)" }
    let xnxqmc: String   // 学年学期
    let kjkcmc: String   // 考级课程名
    let zcj: String      // 总成绩
    let kssj: String     // 考试时间
    let zkzh: String     // 准考证号
    let djmc: String     // 等级
    let cjbzmc: String
    let bz: String

    /// 四六级 ≥425 视为通过，其余 ≥60。
    var isPassed: Bool {
        let score = Int(zcj) ?? 0
        if kjkcmc.contains("英语四级") || kjkcmc.contains("英语六级") { return score >= 425 }
        return score >= 60
    }

    static func parse(_ json: String) throws -> [ExamGradeRecord] {
        guard let data = json.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = obj["rows"] as? [[String: Any]] else {
            throw GradeRecord.ParseError.notJSON
        }
        func s(_ row: [String: Any], _ k: String) -> String { (row[k] as? String) ?? "" }
        return rows.map {
            ExamGradeRecord(xnxqmc: s($0, "xnxqmc"), kjkcmc: s($0, "kjkcmc"), zcj: s($0, "zcj"),
                            kssj: s($0, "kssj"), zkzh: s($0, "zkzh"), djmc: s($0, "djmc"),
                            cjbzmc: s($0, "cjbzmc"), bz: s($0, "bz"))
        }
    }
}
