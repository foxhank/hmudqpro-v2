import SwiftUI

/// 成绩查询：顶部学期切换，列表展示课程成绩（分数、学分、绩点）。
struct GradesView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = GradesViewModel()

    var body: some View {
        List {
            Section {
                Picker(String(localized: "grades.semester"), selection: Binding(
                    get: { vm.selectedSemester },
                    set: { vm.switchSemester($0) })) {
                    ForEach(vm.semesters, id: \.self) { code in
                        Text(GradesViewModel.semesterLabel(code)).tag(code)
                    }
                }
                .pickerStyle(.menu)
            }
            if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if let err = vm.errorMessage {
                Text(err).foregroundStyle(.red).font(.footnote)
            } else if vm.grades.isEmpty {
                Text(String(localized: "grades.empty"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.grades) { g in
                    GradeRow(record: g)
                }
            }
        }
        .navigationTitle(String(localized: "tool.grades"))
        .task(id: auth.studentInfo) {
            // 学期列表起点 = 入学年份：优先学生信息的「年级」，兜底学号前两位（23xxxx → 2023）
            if let year = Self.enrollmentYear(studentInfo: auth.studentInfo) {
                vm.updateStartYear(year)
            }
            await vm.load()
        }
    }

    /// 入学年份。年级字段可能带「级」或为空，取其中的 4 位数字；兜底学号前两位。
    static func enrollmentYear(studentInfo: StudentInfo?) -> Int? {
        if let grade = studentInfo?.grade,
           let m = grade.range(of: #"20\d{2}"#, options: .regularExpression) {
            return Int(grade[m])
        }
        guard let id = KeychainStore.string(forKey: KeychainStore.Keys.studentID),
              id.count >= 2, let yy = Int(id.prefix(2)) else { return nil }
        return 2000 + yy
    }
}

struct GradeRow: View {
    let record: GradeRecord
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.kcmc).font(.headline).foregroundStyle(.primary)
                    Text("\(String(localized: "grades.credits")) \(record.xf) · \(String(localized: "grades.gpa")) \(record.cjjd)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(record.zcj)
                    .font(.title2.bold())
                    .foregroundStyle(record.isPassed ? .green : .red)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            GradeDetailSheet(record: record)
                .presentationDetents([.medium])
        }
    }
}

/// 成绩详情：安卓成绩页点开后的完整字段。
struct GradeDetailSheet: View {
    let record: GradeRecord
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                LabeledContent(String(localized: "grades.detail.score"), value: record.zcj)
                LabeledContent(String(localized: "grades.detail.gpa"), value: record.cjjd)
                LabeledContent(String(localized: "grades.detail.credits"), value: record.xf)
                LabeledContent(String(localized: "grades.detail.method"), value: record.cjfsmc)
                LabeledContent(String(localized: "grades.detail.category"), value: record.kcflmc)
                LabeledContent(String(localized: "grades.detail.classLevel"), value: record.kcdlmc)
                LabeledContent(String(localized: "grades.detail.class"), value: record.jxbmc)
                LabeledContent(String(localized: "grades.detail.teacher"), value: record.teaxms)
                LabeledContent(String(localized: "grades.detail.department"), value: record.kkbmmc)
                LabeledContent(String(localized: "grades.detail.examType"), value: record.ksxzmc)
                LabeledContent(String(localized: "grades.detail.flag"), value: record.cjbzmc)
                if !record.bz.isEmpty {
                    LabeledContent(String(localized: "grades.detail.note"), value: record.bz)
                }
            }
            .navigationTitle(record.kcmc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) { dismiss() }
                }
            }
        }
    }
}

/// 考级查询：等级考试成绩（四六级等）。
struct ExamGradesView: View {
    @StateObject private var vm = ExamGradesViewModel()

    var body: some View {
        List {
            if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if let err = vm.errorMessage {
                Text(err).foregroundStyle(.red).font(.footnote)
            } else if vm.records.isEmpty {
                Text(String(localized: "grades.empty"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.records) { r in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(r.kjkcmc).font(.headline)
                            Spacer()
                            Text(r.zcj).font(.title3.bold())
                                .foregroundStyle(r.isPassed ? .green : .red)
                        }
                        Text("\(r.xnxqmc) · \(r.kssj)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "tool.examGrades"))
        .refreshable { await vm.load() }
        .task { await vm.load() }
    }
}
