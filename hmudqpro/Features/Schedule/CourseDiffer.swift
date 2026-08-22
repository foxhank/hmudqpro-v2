import Foundation

/// 课表变更计算（移植安卓 ScheduleRepository.computeDiff）。
///
/// entryKey = kcmc|jxbdm|zc|xq|jcdm（一条排课记录）
/// courseKey = kcmc|jxbdm（一门课的排课集合）
/// 同 courseKey 的记录有增有删 → 识别为"移动"（时间/地点调整），而非新增+移除。
enum CourseDiffer {
    struct Move: Equatable {
        let courseName: String
        let from: String
        let to: String
    }

    enum Result: Equatable {
        case noChange
        case changed(added: [String], removed: [String], moved: [Move])
    }

    static func diff(old: [Course], new: [Course]) -> Result {
        // entryKey 含教室：纯换教室（时间不变）也视为变动（比安卓更严格，安卓会漏报）
        func entryKey(_ c: Course) -> String { "\(c.kcmc)|\(c.jxbdm)|\(c.zc)|\(c.xq)|\(c.jcdm)|\(c.jxcdmc)" }
        func courseKey(_ c: Course) -> String { "\(c.kcmc)|\(c.jxbdm)" }

        let oldMap = Dictionary(uniqueKeysWithValues: old.map { (entryKey($0), $0) })
        let newMap = Dictionary(uniqueKeysWithValues: new.map { (entryKey($0), $0) })

        let removedKeys = Set(oldMap.keys).subtracting(newMap.keys)
        let addedKeys = Set(newMap.keys).subtracting(oldMap.keys)
        if removedKeys.isEmpty && addedKeys.isEmpty { return .noChange }

        let removed = removedKeys.compactMap { oldMap[$0] }
        let added = addedKeys.compactMap { newMap[$0] }

        // 同门课的移动检测
        let removedByCourse = Dictionary(grouping: removed, by: courseKey)
        let addedByCourse = Dictionary(grouping: added, by: courseKey)

        var moves: [Move] = []
        var movedOldKeys = Set<String>()
        var movedNewKeys = Set<String>()
        for (key, oldList) in removedByCourse {
            guard let newList = addedByCourse[key] else { continue }
            for i in oldList.indices where i < newList.count {
                let o = oldList[i]
                let n = newList[i]
                let locChanged = o.jxcdmc != n.jxcdmc
                let from = o.scheduleDescription + (locChanged ? " (\(o.jxcdmc))" : "")
                let to = n.scheduleDescription + (locChanged ? " (\(n.jxcdmc))" : "")
                moves.append(Move(courseName: o.kcmc, from: from, to: to))
                movedOldKeys.insert(entryKey(o))
                movedNewKeys.insert(entryKey(n))
            }
        }

        let addedDescs = added.filter { !movedNewKeys.contains(entryKey($0)) }
            .map { "\($0.kcmc)（\($0.scheduleDescription)）" }
        let removedDescs = removed.filter { !movedOldKeys.contains(entryKey($0)) }
            .map { "\($0.kcmc)（\($0.scheduleDescription)）" }

        if moves.isEmpty && addedDescs.isEmpty && removedDescs.isEmpty { return .noChange }
        return .changed(added: addedDescs, removed: removedDescs, moved: moves)
    }

    /// 生成提醒弹窗正文（对齐安卓文案：新增/移除/移动 + 提示语）。
    static func alertMessage(_ result: Result) -> String? {
        switch result {
        case .noChange:
            return nil
        case .changed(let added, let removed, let moved):
            var lines: [String] = []
            lines += added.prefix(6).map { String(localized: "course.change.added \($0)") }
            lines += removed.prefix(6).map { String(localized: "course.change.removed \($0)") }
            lines += moved.prefix(6).map { String(localized: "course.change.moved \($0.courseName) \($0.from) \($0.to)") }
            if added.count > 6 { lines.append(String(localized: "course.change.more \(added.count - 6)")) }
            if removed.count > 6 { lines.append(String(localized: "course.change.more \(removed.count - 6)")) }
            if moved.count > 6 { lines.append(String(localized: "course.change.more \(moved.count - 6)")) }
            lines.append(String(localized: "course.change.hint"))
            return lines.joined(separator: "\n")
        }
    }
}
