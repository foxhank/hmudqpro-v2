import SwiftUI

/// 在线选课页：已选/可选列表，多选批量选课，单条选/退。
struct CourseSelectionScreen: View {
    @StateObject private var vm = CourseSelectionViewModel()

    var body: some View {
        List {
            Section {
                HStack {
                    Text(String(format: String(localized: "select.counter"),
                                vm.alreadySelected, vm.maxSelection))
                        .font(.subheadline)
                    Spacer()
                    if !vm.checked.isEmpty {
                        Button(String(format: String(localized: "select.batch"), vm.checked.count)) {
                            Task { await vm.batchSelect() }
                        }
                        .font(.subheadline.bold())
                    }
                }
                if let msg = vm.actionMessage {
                    Text(msg).font(.caption).foregroundStyle(.secondary)
                }
            }
            if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if let err = vm.errorMessage {
                Text(err).foregroundStyle(.red).font(.footnote)
            } else {
                ForEach(vm.courses) { course in
                    SelectableCourseRow(course: course,
                                        checked: vm.checked.contains(course.kcrwdm),
                                        onToggle: { vm.toggle(course) },
                                        onAction: { Task { await vm.act(course) } })
                }
                if vm.courses.isEmpty {
                    Text(String(localized: "select.empty")).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "tool.courseSelect"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.load() }
        .task { await vm.load() }
    }
}

private struct SelectableCourseRow: View {
    let course: SelectableCourse
    let checked: Bool
    let onToggle: () -> Void
    let onAction: () -> Void

    var body: some View {
        HStack {
            if !course.isSelected {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(checked ? Color.accentColor : .secondary)
                    .onTapGesture(perform: onToggle)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(course.kcmc).font(.headline)
                    if course.isSelected {
                        Text(String(localized: "select.chosen"))
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                    }
                }
                Text("\(String(localized: "grades.credits")) \(course.xf) · \(course.teaxm) · \(String(format: String(localized: "select.capacity"), course.pkrs))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onAction) {
                Text(course.isSelected
                     ? String(localized: "select.cancel")
                     : String(localized: "select.pick"))
                    .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .tint(course.isSelected ? .red : .accentColor)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class CourseSelectionViewModel: ObservableObject {
    @Published var courses: [SelectableCourse] = []
    @Published var checked: Set<String> = []
    @Published var maxSelection = 8
    @Published var alreadySelected = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var actionMessage: String?

    private let service: CourseSelectionService

    init(service: CourseSelectionService = CourseSelectionService()) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        checked = []
        defer { isLoading = false }
        do {
            let data = try await service.fetchData()
            courses = data.courses
            maxSelection = data.maxSelection
            alreadySelected = data.alreadySelected
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggle(_ course: SelectableCourse) {
        if checked.contains(course.kcrwdm) {
            checked.remove(course.kcrwdm)
        } else if checked.count < maxSelection - alreadySelected {
            checked.insert(course.kcrwdm)
        }
    }

    func act(_ course: SelectableCourse) async {
        do {
            let result = course.isSelected
                ? try await service.cancel(course: course)
                : try await service.select(course: course)
            actionMessage = result.1
            if result.0 { await load() }
        } catch is CancellationError {
        } catch {
            actionMessage = error.localizedDescription
        }
    }

    func batchSelect() async {
        let picked = courses.filter { checked.contains($0.kcrwdm) }
        for course in picked {
            if let result = try? await service.select(course: course), result.0 {
                actionMessage = result.1
            }
        }
        await load()
    }
}
