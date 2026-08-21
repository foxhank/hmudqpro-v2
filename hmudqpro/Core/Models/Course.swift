import Foundation

/// 课程条目（教务 getCalendar.action 返回的 JSON 行，一周一行）。
/// 字段名保留教务系统的拼音缩写（解码需要），展示用计算属性。
struct Course: Codable, Hashable, Identifiable {
    let kcmc: String      // 课程名称
    let zc: String        // 周次（纯数字字符串，一行一周）
    let xq: String        // 星期几（1-7）
    let qsrq: String      // 开始日期 yyyy-MM-dd
    let jsrq: String      // 结束日期
    let qssj: String      // 开始时间
    let jssj: String      // 结束时间
    let ps: String        // 开始节次
    let pe: String        // 结束节次
    let teaxms: String    // 教师姓名
    let jxcdmc: String    // 教学场地名称
    let jxbmc: String     // 教学班名称
    let jxhjmc: String    // 教学环节名称
    let bgcolor: String   // 背景颜色
    let bz: String        // 备注
    let xqmc: String      // 校区名称

    var id: String { "\(kcmc)-\(jxbmc)-\(zc)-\(xq)-\(ps)" }

    var week: Int? { Int(zc) }
    var weekday: Int? { Int(xq) }
    /// 节次范围（1 开始）。
    var startSlot: Int? { Int(ps) }
    var endSlot: Int? { Int(pe) }
    /// 课时长（节数）。
    var slotCount: Int { (endSlot ?? 0) - (startSlot ?? 0) + 1 }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func s(_ key: CodingKeys) -> String { (try? c.decodeIfPresent(String.self, forKey: key)) ?? "" }
        kcmc = s(.kcmc); zc = s(.zc); xq = s(.xq); qsrq = s(.qsrq); jsrq = s(.jsrq)
        qssj = s(.qssj); jssj = s(.jssj); ps = s(.ps); pe = s(.pe)
        teaxms = s(.teaxms); jxcdmc = s(.jxcdmc); jxbmc = s(.jxbmc)
        jxhjmc = s(.jxhjmc); bgcolor = s(.bgcolor); bz = s(.bz); xqmc = s(.xqmc)
    }

    /// 供测试与预览直接构造。
    init(kcmc: String, zc: String, xq: String, qsrq: String = "", jsrq: String = "",
         qssj: String = "", jssj: String = "", ps: String = "1", pe: String = "2",
         teaxms: String = "", jxcdmc: String = "", jxbmc: String = "", jxhjmc: String = "",
         bgcolor: String = "", bz: String = "", xqmc: String = "") {
        self.kcmc = kcmc; self.zc = zc; self.xq = xq; self.qsrq = qsrq; self.jsrq = jsrq
        self.qssj = qssj; self.jssj = jssj; self.ps = ps; self.pe = pe
        self.teaxms = teaxms; self.jxcdmc = jxcdmc; self.jxbmc = jxbmc
        self.jxhjmc = jxhjmc; self.bgcolor = bgcolor; self.bz = bz; self.xqmc = xqmc
    }
}
