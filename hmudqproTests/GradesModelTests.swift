import XCTest
@testable import hmudqpro

final class GradesModelTests: XCTestCase {
    func testParseGrades() throws {
        let json = """
        {"total":2,"rows":[
          {"xnxqmc":"2025-2026 1","kcmc":"系统解剖学","zcj":"88","cjfsmc":"百分制","xf":"5","cjjd":"3.8","jxbmc":"01","teaxms":"张三"},
          {"xnxqmc":"2025-2026 1","kcmc":"体育","zcj":"合格","cjfsmc":"二级制","xf":"1","cjjd":"","jxbmc":"02"}
        ]}
        """
        let grades = try GradeRecord.parse(json)
        XCTAssertEqual(grades.count, 2)
        XCTAssertTrue(grades[0].isPassed)
        XCTAssertEqual(grades[0].kcmc, "系统解剖学")
        XCTAssertTrue(grades[1].isPassed) // 二级制 合格
    }

    func testParseFailedGrade() throws {
        let json = """
        {"rows":[{"kcmc":"生理学","zcj":"45","cjfsmc":"百分制"}]}
        """
        let grades = try GradeRecord.parse(json)
        XCTAssertFalse(grades[0].isPassed)
    }

    func testParseExamGrades() throws {
        let json = """
        {"rows":[
          {"xnxqmc":"2024-2025 2","kjkcmc":"全国大学英语四级考试","zcj":"430","kssj":"2025-06-14","zkzh":"123","djmc":"四级"},
          {"xnxqmc":"2024-2025 1","kjkcmc":"普通话水平测试","zcj":"87","kssj":"2024-11-01"}
        ]}
        """
        let records = try ExamGradeRecord.parse(json)
        XCTAssertEqual(records.count, 2)
        XCTAssertTrue(records[0].isPassed)  // 四级 430 ≥ 425
        XCTAssertTrue(records[1].isPassed)
    }

    func testSemesterCodeAndLabel() {
        XCTAssertEqual(GradesViewModel.semesterLabel("202401"), "2024-25 1")
        XCTAssertEqual(GradesViewModel.semesterLabel("202402"), "2024-25 2")
        let semesters = GradesViewModel.availableSemesters(startYear: 2023, today: Date(timeIntervalSince1970: 1_756_000_000)) // 2025-08
        XCTAssertEqual(semesters.first, "202501")
        XCTAssertEqual(semesters.count, 6)
    }

    func testParseHTMLThrows() {
        XCTAssertThrowsError(try GradeRecord.parse("<!DOCTYPE html><html>login</html>"))
    }
}
