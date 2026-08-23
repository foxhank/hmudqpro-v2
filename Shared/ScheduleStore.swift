import Foundation
import CryptoKit

/// 课表缓存：JSON 存 App Group UserDefaults（主 App 与 Widget 共享），
/// 附 SHA256 指纹用于增量比对（决定是否需要刷新 Widget）。
final class ScheduleStore {
    static let shared = ScheduleStore()

    private let defaults: UserDefaults
    private static let coursesKey = "schedule.courses"
    private static let fingerprintKey = "schedule.fingerprint"
    private static let fetchedAtKey = "schedule.fetchedAt"

    init?(suiteName: String = "group.cn.foxhank.hmudqpro") {
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    /// 确定性编码器（键排序），保证同一数据编码结果字节一致，指纹才可比。
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    // MARK: - 读写

    func save(_ courses: [Course]) {
        guard let data = try? Self.encoder.encode(courses) else { return }
        defaults.set(data, forKey: Self.coursesKey)
        defaults.set(Self.sha256(data), forKey: Self.fingerprintKey)
        defaults.set(Date().timeIntervalSince1970, forKey: Self.fetchedAtKey)
    }

    func load() -> [Course] {
        guard let data = defaults.data(forKey: Self.coursesKey) else { return [] }
        return (try? JSONDecoder().decode([Course].self, from: data)) ?? []
    }

    var fetchedAt: Date? {
        let t = defaults.double(forKey: Self.fetchedAtKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// 数据内容是否与当前缓存一致（用于跳过无谓的 Widget 刷新）。
    func isSameAsCache(_ courses: [Course]) -> Bool {
        guard let data = try? Self.encoder.encode(courses) else { return false }
        return defaults.string(forKey: Self.fingerprintKey) == Self.sha256(data)
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
