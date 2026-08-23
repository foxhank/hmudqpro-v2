import Foundation
import SwiftUI

/// 教师评价（移植安卓）：当前学期评教任务列表与完成状态（只读查询）。
struct TeacherEvaluation: Identifiable, Equatable {
    var id: String { "\(teabh)|\(kcmc)|\(dm)" }
    let teabh: String
    let teaxm: String     // 教师姓名
    let kcmc: String
    let jxhjmc: String    // 教学环节
    let xnxqmc: String
    let qsrq: String
    let jkrq: String
    let pjdm: String      // 评价代码，非空 = 已评
    let dm: String

    var isEvaluated: Bool { !pjdm.isEmpty }
}

final class EvaluationService {
    enum EvalError: Error, LocalizedError {
        case sessionExpired
        case failed(String)
        var errorDescription: String? {
            switch self {
            case .sessionExpired: return String(localized: "error.sessionExpired")
            case .failed(let m): return m
            }
        }
    }

    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func fetchEvaluations() async throws -> [TeacherEvaluation] {
        do {
            return try await fetchOnce()
        } catch is EvalError {
            guard await SessionKeeper.shared.reloginIfPossible() else { throw EvalError.sessionExpired }
            return try await fetchOnce()
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw error }
            throw EvalError.failed(error.localizedDescription)
        }
    }

    private func fetchOnce() async throws -> [TeacherEvaluation] {
        // 评价页探测登录态
        let (pageData, _) = try await client.request(
            APIConfig.jwcTeacherEvalPageURL, userAgent: APIConfig.webUserAgentShort,
            headers: ["Referer": APIConfig.jwcDesktopURL.absoluteString])
        let pageHtml = String(data: pageData, encoding: .utf8) ?? ""
        if !pageHtml.contains("教师评价") { throw EvalError.sessionExpired }

        let body = "xnxqdm=\(Self.currentSemesterCode())&primarySort=%20dm%20asc&page=1&rows=100&sort=jkrq&order=asc"
            .data(using: .utf8)
        let (data, _) = try await client.request(
            APIConfig.jwcTeacherEvalListURL, method: "POST", body: body,
            userAgent: APIConfig.webUserAgentShort,
            headers: [
                "Referer": APIConfig.jwcTeacherEvalPageURL.absoluteString,
                "X-Requested-With": "XMLHttpRequest",
            ])
        let json = String(data: data, encoding: .utf8) ?? ""
        return try Self.parse(json)
    }

    /// 与成绩页同规则：8 月起 = 当年 01 学期，2~7 月 = 上一年 02 学期。
    static func currentSemesterCode() -> String {
        let c = Calendar.current
        let y = c.component(.year, from: Date())
        let m = c.component(.month, from: Date())
        return m >= 8 ? "\(y)01" : "\(y - 1)02"
    }

    static func parse(_ json: String) throws -> [TeacherEvaluation] {
        guard let data = json.data(using: .utf8),
              json.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{"),
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = obj["rows"] as? [[String: Any]] else {
            throw EvalError.sessionExpired
        }
        func s(_ r: [String: Any], _ k: String) -> String { (r[k] as? String) ?? "" }
        return rows.map {
            TeacherEvaluation(teabh: s($0, "teabh"), teaxm: s($0, "teaxm"), kcmc: s($0, "kcmc"),
                              jxhjmc: s($0, "jxhjmc"), xnxqmc: s($0, "xnxqmc"), qsrq: s($0, "qsrq"),
                              jkrq: s($0, "jkrq"), pjdm: s($0, "pjdm"), dm: s($0, "dm"))
        }
    }
}

// MARK: - View

struct EvaluationView: View {
    @StateObject private var vm = EvaluationViewModel()

    var body: some View {
        List {
            if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if let err = vm.errorMessage {
                Text(err).foregroundStyle(.red).font(.footnote)
            } else if vm.evaluations.isEmpty {
                Text(String(localized: "eval.empty")).foregroundStyle(.secondary)
            } else {
                ForEach(vm.evaluations) { e in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(e.kcmc).font(.headline)
                            Spacer()
                            Text(e.isEvaluated
                                 ? String(localized: "eval.done")
                                 : String(localized: "eval.pending"))
                                .font(.caption.bold())
                                .foregroundStyle(e.isEvaluated ? .green : .orange)
                        }
                        if !e.teaxm.isEmpty {
                            Text(String(format: String(localized: "eval.teacher"), e.teaxm))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if !e.jxhjmc.isEmpty {
                            Text(e.jxhjmc).font(.caption).foregroundStyle(.secondary)
                        }
                        if !e.qsrq.isEmpty || !e.jkrq.isEmpty {
                            Text("\(e.qsrq) ~ \(e.jkrq)")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(String(localized: "tool.evaluation"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.load() }
        .task { await vm.load() }
    }
}

@MainActor
final class EvaluationViewModel: ObservableObject {
    @Published var evaluations: [TeacherEvaluation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: EvaluationService

    init(service: EvaluationService = EvaluationService()) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            evaluations = try await service.fetchEvaluations()
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
