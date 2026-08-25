import Foundation

/// 调试开关（真机功能测试用）：写入 UserDefaults，**重启 app 后生效**。
///
/// - 课程调换：把缓存课表里两门课的上课时间互换，重启后课表页刷新时会
///   与教务真实数据 diff 出「移动」，用于测试课表变动提醒弹窗。
/// - 伪造更新 / 手动触发节日、生日彩蛋：开屏检查优先读这里的值。
enum DebugStore {
    private static let swapKey = "debug.courseSwap"
    private static let fakeUpdateKey = "debug.fakeUpdate"
    private static let holidayKey = "debug.forceHoliday"
    private static let birthdayKey = "debug.forceBirthday"

    // MARK: - 课程调换

    /// 要调换的两门课名（kcmc）；空数组 = 未启用。
    static var courseSwap: [String] {
        UserDefaults.standard.stringArray(forKey: swapKey) ?? []
    }

    static func setCourseSwap(_ names: [String]?) {
        if let names, names.count == 2 {
            UserDefaults.standard.set(names, forKey: swapKey)
        } else {
            UserDefaults.standard.removeObject(forKey: swapKey)
        }
    }

    /// 把名字匹配的两门课的排课字段（星期/节次/时间）互换；未配置或不匹配则原样返回。
    static func applySwap(_ courses: [Course]) -> [Course] {
        let names = courseSwap
        guard names.count == 2 else { return courses }
        guard let i = courses.firstIndex(where: { $0.kcmc == names[0] }),
              let j = courses.firstIndex(where: { $0.kcmc == names[1] }), i != j
        else { return courses }
        var result = courses
        let a = courses[i], b = courses[j]
        func swapped(_ base: Course, time from: Course) -> Course {
            Course(kcmc: base.kcmc, zc: base.zc, xq: from.xq, qsrq: base.qsrq, jsrq: base.jsrq,
                   qssj: from.qssj, jssj: from.jssj, ps: from.ps, pe: from.pe,
                   teaxms: base.teaxms, jxcdmc: base.jxcdmc, jxbmc: base.jxbmc, jxbdm: base.jxbdm,
                   jxhjmc: base.jxhjmc, bgcolor: base.bgcolor, bz: base.bz, xqmc: base.xqmc,
                   jcdm: from.jcdm)
        }
        result[i] = swapped(a, time: b)
        result[j] = swapped(b, time: a)
        return result
    }

    // MARK: - 伪造更新

    static var fakeUpdate: UpdateInfo? {
        guard let data = UserDefaults.standard.data(forKey: fakeUpdateKey) else { return nil }
        return try? JSONDecoder().decode(UpdateInfo.self, from: data)
    }

    static func setFakeUpdate(_ info: UpdateInfo?) {
        if let info, let data = try? JSONEncoder().encode(info) {
            UserDefaults.standard.set(data, forKey: fakeUpdateKey)
        } else {
            UserDefaults.standard.removeObject(forKey: fakeUpdateKey)
        }
    }

    // MARK: - 开屏彩蛋

    static var forceHoliday: Bool {
        get { UserDefaults.standard.bool(forKey: holidayKey) }
        set { UserDefaults.standard.set(newValue, forKey: holidayKey) }
    }

    static var forceBirthday: Bool {
        get { UserDefaults.standard.bool(forKey: birthdayKey) }
        set { UserDefaults.standard.set(newValue, forKey: birthdayKey) }
    }
}
