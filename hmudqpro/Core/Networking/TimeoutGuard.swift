import Foundation

/// 全局超时守卫：保证任何挂起操作最多运行指定秒数。
///
/// 教务系统偶发「卡死」（TCP 连着但完全不返回数据，一直到 60s 系统超时），
/// 此组件用「请求 vs 计时器」赛跑强制截断，避免用户干等。
enum TimeoutGuard {
    enum TimeoutError: Error, LocalizedError {
        case timedOut(seconds: Int)
        var errorDescription: String? {
            switch self {
            case .timedOut(let seconds): return "教务系统暂时无响应（超过 \(seconds) 秒），请稍后重试"
            }
        }
    }

    /// 默认全局上限。
    static let defaultLimit: Int = 10

    /// 执行操作，超过 `seconds` 秒未完成则抛出 `TimeoutError`。
    /// 注意：超时后底层任务会被取消（URLSession 会中断请求）。
    static func withTimeout<T: Sendable>(
        seconds: Int = defaultLimit,
        label: String = "",
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                throw TimeoutError.timedOut(seconds: seconds)
            }
            guard let result = try await group.next() else {
                throw TimeoutError.timedOut(seconds: seconds)
            }
            group.cancelAll() // 另一个任务（计时器或操作）不再需要
            return result
        }
    }
}
