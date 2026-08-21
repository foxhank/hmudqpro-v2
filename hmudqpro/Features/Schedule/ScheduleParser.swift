import Foundation

/// 课表响应解析：区分 JSON（正常）与 HTML（登录失效）。
enum ScheduleParser {
    enum ParseError: Error, LocalizedError {
        case htmlResponse       // 返回了 HTML 登录页 → 登录态失效
        case invalidJSON
        case emptyData
        var errorDescription: String? {
            switch self {
            case .htmlResponse: return "登录已失效"
            case .invalidJSON: return "课表数据格式异常"
            case .emptyData: return "课表数据为空"
            }
        }
    }

    /// 解析 getCalendar.action 的响应体。
    static func parse(_ body: String) throws -> [Course] {
        guard !body.isEmpty else { throw ParseError.emptyData }
        guard let data = body.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { throw ParseError.htmlResponse }
        guard !jsonArray.isEmpty else { throw ParseError.emptyData }
        let jsonData = try JSONSerialization.data(withJSONObject: jsonArray)
        return try JSONDecoder().decode([Course].self, from: jsonData)
    }

    /// 当前学期查询范围（教务按日期范围返回课表）。
    /// 秋季 8/15～次年 1/20，春季 2/20～6/30。
    static func currentSemesterRange(today: Date = Date()) -> (start: String, end: String) {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: today)
        let year = calendar.component(.year, from: today)
        if month >= 8 || month <= 1 {
            let startYear = month >= 8 ? year : year - 1
            return ("\(startYear)-08-15", "\(startYear + 1)-01-20")
        } else {
            return ("\(year)-02-20", "\(year)-06-30")
        }
    }
}
