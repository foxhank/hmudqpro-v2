import Foundation

/// 成绩页状态：学期切换 + 拉取课程成绩。
@MainActor
final class GradesViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var grades: [GradeRecord] = []
    @Published var semesters: [String] = []
    @Published var selectedSemester = ""
    @Published var errorMessage: String?

    private let service: GradesService
    /// 入学年份（学生信息「年级」），决定学期列表起点。默认当前年，登录信息就绪后 updateStartYear 修正。
    private var startYear: Int

    init(service: GradesService = GradesService(), startYear: Int? = nil) {
        self.service = service
        self.startYear = startYear ?? Calendar.current.component(.year, from: Date())
        semesters = Self.availableSemesters(startYear: self.startYear)
        selectedSemester = semesters.first ?? Self.currentSemesterCode()
    }

    func updateStartYear(_ year: Int) {
        guard year != startYear else { return }
        startYear = year
        semesters = Self.availableSemesters(startYear: year)
        if !semesters.contains(selectedSemester) { selectedSemester = semesters.first ?? selectedSemester }
    }

    /// "202401" → "2024-25 1"。
    static func semesterLabel(_ code: String) -> String {
        guard code.count == 6, let year = Int(code.prefix(4)) else { return code }
        let sem = code.hasSuffix("01") ? "1" : "2"
        return "\(year)-\(String(year + 1).suffix(2)) \(sem)"
    }

    /// 当前学期码：8月及以后 = 当年 01 学期；2~7月 = 上一年 02 学期。
    static func currentSemesterCode() -> String {
        let c = Calendar.current
        let y = c.component(.year, from: Date())
        let m = c.component(.month, from: Date())
        return m >= 8 ? "\(y)01" : "\(y - 1)02"
    }

    static func availableSemesters(startYear: Int, today: Date = Date()) -> [String] {
        let y = Calendar.current.component(.year, from: today)
        var codes: [String] = []
        for year in startYear...y {
            codes.append("\(year)01")
            codes.append("\(year)02")
        }
        return codes.reversed()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            grades = try await service.fetchGrades(semesterCode: selectedSemester)
        } catch is CancellationError {
            // 静默
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func switchSemester(_ code: String) {
        guard code != selectedSemester else { return }
        selectedSemester = code
        Task { await load() }
    }
}

/// 等级考试成绩（考级查询）页状态。
@MainActor
final class ExamGradesViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var records: [ExamGradeRecord] = []
    @Published var errorMessage: String?

    private let service: GradesService

    init(service: GradesService = GradesService()) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            records = try await service.fetchExamGrades()
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
