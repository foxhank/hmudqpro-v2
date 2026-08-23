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
    let jxbdm: String     // 教学班代码（课表变更 diff 的分组键）
    let jxhjmc: String    // 教学环节名称
    let bgcolor: String   // 背景颜色（教务字段，安卓端未使用）
    let bz: String        // 备注
    let xqmc: String      // 校区名称
    let jcdm: String      // 节次码（两位一节："01"=第1节、"0102"=1-2节、"01020304"=1-4节）

    var id: String { "\(kcmc)-\(jxbmc)-\(zc)-\(xq)-\(ps)" }

    var week: Int? { Int(zc) }
    var weekday: Int? { Int(xq) }
    var startSlot: Int? { Int(ps) }
    var endSlot: Int? { Int(pe) }

    /// 一天固定 6 个大节（1-2、3-4、…、11-12 节两两配对，参照安卓端）。
    static let bigSlotsPerDay = 6

    /// 该课占用的大节索引（0...5）。优先按节次码解析，缺失时按 ps/pe 推算。
    var bigSlotIndices: [Int] {
        if jcdm.count > 2 {
            // 长码：每 2 字符一个节号，节号 N → 大节 (N-1)/2
            var indices: [Int] = []
            var i = 0
            while i + 1 < jcdm.count {
                if let period = Int(jcdm.dropFirst(i).prefix(2)) {
                    let slot = (period - 1) / 2
                    if 0...5 ~= slot, !indices.contains(slot) { indices.append(slot) }
                }
                i += 2
            }
            if !indices.isEmpty { return indices.sorted() }
        }
        // 兜底：按起止节次区间换算（注意教务 ps/pe 是 1 起始）
        if let s = startSlot, let e = endSlot, s >= 1, e >= s {
            return Set((s...e).map { min(max(($0 - 1) / 2, 0), 5) }).sorted()
        }
        return []
    }

    /// 起始大节与跨度（跨大节的课卡片连成一块，如 1-4 节跨 2 个大节）。
    var firstBigSlot: Int? { bigSlotIndices.first }
    var bigSlotSpan: Int { bigSlotIndices.count }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func s(_ key: CodingKeys) -> String { (try? c.decodeIfPresent(String.self, forKey: key)) ?? "" }
        kcmc = s(.kcmc); zc = s(.zc); xq = s(.xq); qsrq = s(.qsrq); jsrq = s(.jsrq)
        qssj = s(.qssj); jssj = s(.jssj); ps = s(.ps); pe = s(.pe)
        teaxms = s(.teaxms); jxcdmc = s(.jxcdmc); jxbmc = s(.jxbmc); jxbdm = s(.jxbdm)
        jxhjmc = s(.jxhjmc); bgcolor = s(.bgcolor); bz = s(.bz); xqmc = s(.xqmc)
        jcdm = s(.jcdm)
    }

    /// 供测试与预览直接构造。
    init(kcmc: String, zc: String, xq: String, qsrq: String = "", jsrq: String = "",
         qssj: String = "", jssj: String = "", ps: String = "1", pe: String = "2",
         teaxms: String = "", jxcdmc: String = "", jxbmc: String = "", jxbdm: String = "",
         jxhjmc: String = "", bgcolor: String = "", bz: String = "", xqmc: String = "", jcdm: String = "") {
        self.kcmc = kcmc; self.zc = zc; self.xq = xq; self.qsrq = qsrq; self.jsrq = jsrq
        self.qssj = qssj; self.jssj = jssj; self.ps = ps; self.pe = pe
        self.teaxms = teaxms; self.jxcdmc = jxcdmc; self.jxbmc = jxbmc; self.jxbdm = jxbdm
        self.jxhjmc = jxhjmc; self.bgcolor = bgcolor; self.bz = bz; self.xqmc = xqmc
        self.jcdm = jcdm
    }

    // MARK: - 排课描述（课表变更提醒用，格式对齐安卓 scheduleDescription）

    /// 6 大节起止时间。
    static let slotTimeRanges = [
        ("8:00", "9:35"), ("9:55", "11:30"), ("13:30", "15:05"),
        ("15:25", "17:00"), ("18:00", "19:30"), ("19:35", "21:10"),
    ]

    private static let dayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    /// 展示时间，如 "8:00-11:30"。
    var displayTimeText: String {
        let indices = bigSlotIndices
        guard let first = indices.first, let last = indices.last,
              first < Self.slotTimeRanges.count, last < Self.slotTimeRanges.count else { return jcdm }
        return "\(Self.slotTimeRanges[first].0)-\(Self.slotTimeRanges[last].1)"
    }

    /// 排课描述："第3周 周四 8:00-11:30"。
    var scheduleDescription: String {
        let dayIndex = ((weekday ?? 1) - 1).clamped(to: 0...6)
        return "第\(zc)周 周\(Self.dayLabels[dayIndex]) \(displayTimeText)"
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
