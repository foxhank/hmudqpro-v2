import SwiftUI

// MARK: - 节日接口

/// /holiday 返回（数组或单对象）：{date: "MM-DD", description, url}，与今天日期匹配才有彩蛋。
struct HolidayInfo: Equatable {
    let description: String
    let imageURL: URL?
}

enum HolidayService {
    static func todayHoliday() async throws -> HolidayInfo? {
        let url = URL(string: APIConfig.backendBase.absoluteString + APIConfig.holidayPath)!
        // 独立 3s 请求超时：开屏检查不能拖启动（APIClient 默认 10s 太长）
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 3
        let (data, resp) = try await URLSession(configuration: config).data(from: url)
        guard (200...299).contains((resp as? HTTPURLResponse)?.statusCode ?? 0) else { return nil }
        return Self.matchToday(String(data: data, encoding: .utf8) ?? "")
    }

    /// 纯函数：从响应里找今天（MM-DD）的节日。
    static func matchToday(_ body: String, today: String = Self.todayString) -> HolidayInfo? {
        func parse(_ obj: [String: Any]) -> HolidayInfo? {
            guard let date = obj["date"] as? String, date == today,
                  let desc = obj["description"] as? String else { return nil }
            return HolidayInfo(description: desc, imageURL: (obj["url"] as? String).flatMap(URL.init))
        }
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        if let list = json as? [[String: Any]] {
            return list.compactMap(parse).first
        }
        if let obj = json as? [String: Any], !(obj.isEmpty) {
            return parse(obj)
        }
        return nil
    }

    static var todayString: String {
        let c = Calendar.current.dateComponents([.month, .day], from: Date())
        return String(format: "%02d-%02d", c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - 彩蛋类型

enum SpecialDay: Equatable {
    case birthday(name: String)
    case holiday(HolidayInfo)

    /// 本地生日优先于线上节日（对齐安卓 HolidayRepository）；调试开关最优先。
    @MainActor
    static func detect() async -> SpecialDay? {
        if DebugStore.forceBirthday {
            let name = AuthViewModel.savedStudentInfo?.name ?? "同学"
            return .birthday(name: name)
        }
        if DebugStore.forceHoliday {
            return .holiday(HolidayInfo(description: "【调试】节日彩蛋测试",
                                        imageURL: nil))
        }
        if let info = AuthViewModel.savedStudentInfo, Self.isBirthday(info.birthday) {
            return .birthday(name: info.name.isEmpty ? info.studentID : info.name)
        }
        if let holiday = try? await HolidayService.todayHoliday() {
            return .holiday(holiday)
        }
        return nil
    }

    /// 生日串（如 2004-06-01 / 2004年6月1日）的月日是否是今天。
    static func isBirthday(_ birthday: String, today: String = HolidayService.todayString) -> Bool {
        guard let m = birthday.range(of: #"\d{1,2}"#, options: .regularExpression) else { return false }
        let afterMonth = String(birthday[m.upperBound...])
        guard let d = afterMonth.range(of: #"\d{1,2}"#, options: .regularExpression) else { return false }
        return String(format: "%02d-%02d", Int(birthday[m]) ?? 0, Int(afterMonth[d]) ?? 0) == today
    }
}

// MARK: - 开屏协调器

/// 开屏流程状态机 + 跨页传递检查更新结果（课表页弹更新框）。
@MainActor
final class SplashCoordinator: ObservableObject {
    static let shared = SplashCoordinator()

    enum Phase: Equatable {
        case loading
        case special(SpecialDay)
        case finished
    }

    @Published var phase: Phase = .loading
    /// 开屏检查到的新版本；进主界面后由课表页弹窗消费。
    @Published var pendingUpdate: UpdateInfo?
    private var started = false

    /// 开屏总预算 3s：并行查更新 + 查彩蛋 + 等会话恢复，到点强制进入主界面。
    func start(auth: AuthViewModel) {
        guard !started else { return }
        started = true
        // UI 测试直通：-uitest-bypass-login 跳过开屏检查直接进主界面（配合模拟器截图调试）
        if CommandLine.arguments.contains("-uitest-bypass-login") {
            auth.isLoggedIn = true
            auth.restoreFinished = true
            phase = .finished
            return
        }
        Task { await run(auth: auth) }
    }

    private func run(auth: AuthViewModel) async {
        let deadline = Date().addingTimeInterval(3)

        // 会话恢复不设 3s 上限（网络慢仍继续跑，完成后 RootView 自动切换），
        // 但开屏最多等到 deadline。
        Task { await auth.restoreOnLaunch() }

        let dayTask = Task { await SpecialDay.detect() }
        let updateTask = Task { try? await TimeoutGuard.withTimeout(seconds: 3) {
            try await UpdateService.check()
        } }
        let day = await dayTask.value ?? nil
        // 调试伪造的更新优先于真实接口
        let networkUpdate = await updateTask.value ?? nil
        let updateInfo = DebugStore.fakeUpdate ?? networkUpdate
        if let info = updateInfo {
            pendingUpdate = info
        }

        // 剩余预算内等会话恢复结束，超时强制放行
        while Date() < deadline && !auth.restoreFinished {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        if let day {
            phase = .special(day) // 彩蛋停留 4s 或用户点跳过
        } else {
            phase = .finished
        }
    }

    func skip() { phase = .finished }
}

// MARK: - 开屏 UI

/// 开屏页：检查中显示 logo + 加载圈；彩蛋（生日/节日）全屏展示，右上角 4s 倒数跳过。
struct SplashView: View {
    @ObservedObject var coordinator: SplashCoordinator
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        ZStack {
            switch coordinator.phase {
            case .loading:
                loadingContent
            case .special(let day):
                specialDayContent(day)
            case .finished:
                Color.clear
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            if case .special = coordinator.phase {
                SplashSkipButton { coordinator.skip() }
                    .padding(20)
            }
        }
    }

    private var loadingContent: some View {
        VStack(spacing: 16) {
            Image("AppLogo")
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22))
            Text(String(localized: "app.name"))
                .font(.title2.bold())
            ProgressView()
        }
    }

    @ViewBuilder
    private func specialDayContent(_ day: SpecialDay) -> some View {
        switch day {
        case .birthday(let name):
            ZStack {
                LinearGradient(colors: [.pink.opacity(0.25), .purple.opacity(0.2), .orange.opacity(0.15)],
                               startPoint: .top, endPoint: .bottom)
                VStack(spacing: 20) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.pink)
                    Text(String(localized: "splash.happyBirthday \(name)"))
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Text(String(localized: "splash.birthdayWish"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        case .holiday(let holiday):
            ZStack {
                Color(.systemBackground)
                VStack(spacing: 16) {
                    if let url = holiday.imageURL {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)
                    } else {
                        Image(systemName: "party.popper.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.orange)
                    }
                    Text(holiday.description)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
    }
}

/// 彩蛋右上角跳过按钮（4s 倒数，到点自动跳过）。
struct SplashSkipButton: View {
    let action: () -> Void
    @State private var remaining = 4

    var body: some View {
        Button(String(localized: "splash.skip \(remaining)"), action: { action() })
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .task {
                while remaining > 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    remaining -= 1
                }
                action()
            }
    }
}
