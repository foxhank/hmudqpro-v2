import SwiftUI

/// 空教室查询：日期 + 教学楼筛选，展示各教室当天占用节次（空闲一眼可见）。
struct EmptyClassroomView: View {
    @StateObject private var vm = ClassroomViewModel()

    var body: some View {
        List {
            Section {
                DatePicker(String(localized: "classroom.date"), selection: $vm.date,
                           displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                Menu {
                    Button(String(localized: "classroom.allBuildings")) { vm.filterBuilding = nil }
                    ForEach(vm.buildingNames, id: \.self) { name in
                        Button(name) { vm.filterBuilding = name }
                    }
                } label: {
                    HStack {
                        Text(String(localized: "classroom.building"))
                        Spacer()
                        Text(vm.filterBuilding ?? String(localized: "classroom.allBuildings"))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if let err = vm.errorMessage {
                Text(err).foregroundStyle(.red).font(.footnote)
            } else {
                ForEach(vm.filteredRooms) { room in
                    ClassroomRoomRow(room: room)
                }
                if vm.filteredRooms.isEmpty {
                    Text(String(localized: "classroom.empty")).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "tool.emptyClassroom"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.load() }
        .task { await vm.load() }
        .onChange(of: vm.date) { _ in Task { await vm.load() } }
    }
}

/// 一个教室：名称 + 当天占用情况（空闲大节高亮）。
struct ClassroomRoomRow: View {
    let room: ClassroomRoom

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(room.name).font(.headline)
                Spacer()
                if room.isAllFree {
                    Label(String(localized: "classroom.allFree"), systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }
            HStack(spacing: 4) {
                // 6 大节：占用显示课名首字提示，空闲绿色
                ForEach(0..<6, id: \.self) { slot in
                    if let course = room.occupiedBy[slot] {
                        Text("\(slot + 1)")
                            .font(.caption2.bold())
                            .frame(maxWidth: .infinity, minHeight: 22)
                            .background(Color.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(.red)
                            .help(course)
                    } else {
                        Text("\(slot + 1)")
                            .font(.caption2.bold())
                            .frame(maxWidth: .infinity, minHeight: 22)
                            .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(.green)
                    }
                }
            }
            if !room.occupiedCourses.isEmpty {
                Text(room.occupiedCourses.joined(separator: "、"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

/// 一个教室的当天占用情况：大节索引(0...5) → 占用课程名。
struct ClassroomRoom: Identifiable, Equatable {
    let name: String
    let occupiedBy: [Int: String]
    var id: String { name }
    var isAllFree: Bool { occupiedBy.isEmpty }
    var occupiedCourses: [String] { Array(Set(occupiedBy.values)).sorted() }
}

// MARK: - ViewModel

/// 教室视图模型：一天占用 → 按教室聚合（教务节次号 → 6 大节 (N-1)/2）。
@MainActor
final class ClassroomViewModel: ObservableObject {
    @Published var date = Date()
    @Published var filterBuilding: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private var rooms: [ClassroomRoom] = []
    @Published private(set) var buildings: [ClassroomBuilding] = []

    private let client = APIClient.shared
    private var loadedDateKey = ""

    var buildingNames: [String] { buildings.map(\.buildingName) }

    var filteredRooms: [ClassroomRoom] {
        guard let filterBuilding else { return rooms }
        let code = buildings.first { $0.buildingName == filterBuilding }?.buildingCode
        return rooms.filter { room in
            // 教室名一般含楼名前缀；按所选楼的排课教室码匹配
            buildings.first { $0.buildingCode == code }?.schedules.contains {
                $0.classroomName == room.name
            } ?? false
        }
    }

    func load() async {
        let key = Self.dayString(date)
        if key == loadedDateKey, !buildings.isEmpty { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let body = try JSONSerialization.data(withJSONObject: ["date": key])
            let (data, _) = try await client.request(
                APIConfig.classroomURL, method: "POST", body: body,
                userAgent: APIConfig.appUserAgent,
                headers: ["Content-Type": "application/json"])
            let result = try ClassroomParser.parse(String(data: data, encoding: .utf8) ?? "")
            buildings = result.buildings
            rooms = Self.aggregateRooms(result.buildings)
            loadedDateKey = key
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 楼 → 排课 → 按教室聚合占用大节。
    static func aggregateRooms(_ buildings: [ClassroomBuilding]) -> [ClassroomRoom] {
        var byRoom: [String: [Int: String]] = [:]
        for building in buildings {
            for s in building.schedules {
                var occupied = byRoom[s.classroomName] ?? [:]
                for period in s.periodSlots {
                    let slot = min(max((period - 1) / 2, 0), 5)
                    if occupied[slot] == nil { occupied[slot] = s.courseName }
                }
                byRoom[s.classroomName] = occupied
            }
        }
        return byRoom
            .map { ClassroomRoom(name: $0.key, occupiedBy: $0.value) }
            .sorted { lhs, rhs in
                let lFree = lhs.occupiedBy.count, rFree = rhs.occupiedBy.count
                if lFree != rFree { return lFree < rFree }   // 越空越前
                return lhs.name < rhs.name
            }
    }

    static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}
