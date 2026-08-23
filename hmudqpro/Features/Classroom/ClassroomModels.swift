import Foundation

/// 空教室（移植安卓 ClassroomModels，数据来自自建后端聚合教务课表）。
struct ClassroomSchedule: Identifiable, Equatable {
    var id: String { recordId }
    let recordId: String
    let periods: String       // 占用节次，逗号分隔
    let courseName: String
    let classroomName: String
    let classroomCode: String
    let className: String
    let teacherName: String
    let teachingMethod: String
    let studentCount: Int
    let weekNumber: Int
    let weekday: Int

    var periodSlots: [Int] {
        periods.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
}

struct ClassroomBuilding: Identifiable, Equatable {
    var id: String { buildingCode }
    let buildingCode: String
    let buildingName: String
    let campusName: String
    let scheduleCount: Int
    let schedules: [ClassroomSchedule]
}

enum ClassroomParser {
    struct Result: Equatable {
        let buildings: [ClassroomBuilding]
        let date: String
        let cacheStatus: String
    }

    static func parse(_ json: String) throws -> Result {
        let data = json.data(using: .utf8) ?? Data()
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard obj["success"] as? Bool == true, let payload = obj["data"] as? [String: Any] else {
            throw ParseError.api(obj["message"] as? String ?? "unknown")
        }
        let date = payload["date"] as? String ?? ""
        let buildingsArray = payload["buildings"] as? [[String: Any]] ?? []
        let buildings = buildingsArray.map { b -> ClassroomBuilding in
            let schedules = (b["schedules"] as? [[String: Any]] ?? []).map { s in
                ClassroomSchedule(
                    recordId: s["recordId"] as? String ?? "",
                    periods: s["periods"] as? String ?? "",
                    courseName: s["courseName"] as? String ?? "",
                    classroomName: s["classroomName"] as? String ?? "",
                    classroomCode: s["classroomCode"] as? String ?? "",
                    className: s["className"] as? String ?? "",
                    teacherName: s["teacherName"] as? String ?? "",
                    teachingMethod: s["teachingMethod"] as? String ?? "",
                    studentCount: s["studentCount"] as? Int ?? 0,
                    weekNumber: s["weekNumber"] as? Int ?? 0,
                    weekday: s["weekday"] as? Int ?? 0)
            }
            return ClassroomBuilding(buildingCode: b["buildingCode"] as? String ?? "",
                                     buildingName: b["buildingName"] as? String ?? "",
                                     campusName: b["campusName"] as? String ?? "",
                                     scheduleCount: b["scheduleCount"] as? Int ?? 0,
                                     schedules: schedules)
        }
        return Result(buildings: buildings, date: date, cacheStatus: obj["cache_status"] as? String ?? "")
    }

    enum ParseError: Error, LocalizedError {
        case api(String)
        var errorDescription: String? {
            switch self {
            case .api(let m): return m
            }
        }
    }
}
