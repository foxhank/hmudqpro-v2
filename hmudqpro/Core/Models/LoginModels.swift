import Foundation

/// 登录结果（纯数据，不含网络细节）。
struct LoginResult {
    var success: Bool
    var message: String
    var studentInfo: StudentInfo?
}

/// 学生基本信息（从教务 xjkpxx 页面解析）。
struct StudentInfo: Codable, Equatable {
    var name: String
    var studentID: String
    var college: String
    var major: String
    var className: String
    var grade: String
    var birthday: String
    var gender: String
}
