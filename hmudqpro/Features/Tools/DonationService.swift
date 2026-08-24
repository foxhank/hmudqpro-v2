import Foundation
import CryptoKit

/// 打赏后端服务（对齐 v1 DonationAPIManager）：MD5 签名鉴权。
final class DonationService {
    struct DonationRanking: Identifiable, Equatable {
        let id: String          // user_id_hash
        let nickname: String
        let donationCount: Int
        let isCurrentUser: Bool
    }

    struct Overview: Decodable, Equatable {
        let projectName: String
        let projectImageURL: String
        let proofImageURL: String

        enum CodingKeys: String, CodingKey {
            case projectName = "project_name"
            case projectImageURL = "project_image_url"
            case proofImageURL = "proof_image_url"
        }
    }

    enum DonationError: Error, LocalizedError {
        case api(String)
        case decode
        var errorDescription: String? {
            switch self {
            case .api(let m): return m
            case .decode: return String(localized: "donation.error.decode")
            }
        }
    }

    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    private var userID: String {
        KeychainStore.string(forKey: KeychainStore.Keys.studentID) ?? ""
    }

    /// 鉴权头（与 v1 相同：hmudq+timestamp+nonce+user_id+secret 的 MD5）。
    private func authHeaders(userID: String) -> [String: String] {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let nonce = UUID().uuidString
        let sign = "hmudq\(timestamp)\(nonce)\(userID)\(APIConfig.donateSecretKey)"
        let md5 = Insecure.MD5.hash(data: Data(sign.utf8)).map { String(format: "%02x", $0) }.joined()
        return [
            "Authorization": "Bearer \(md5)",
            "X-Timestamp": timestamp,
            "X-Nonce": nonce,
        ]
    }

    private func request<T: Encodable>(_ url: URL, body: T) async throws -> [String: Any] {
        var headers = authHeaders(userID: userID)
        headers["Content-Type"] = "application/json"
        let data = try JSONEncoder().encode(body)
        let (respData, _) = try await client.request(url, method: "POST", body: data,
                                                     userAgent: APIConfig.appUserAgent,
                                                     headers: headers)
        guard let obj = try? JSONSerialization.jsonObject(with: respData) as? [String: Any] else {
            throw DonationError.decode
        }
        guard obj["code"] as? String == "0" else {
            throw DonationError.api(obj["message"] as? String ?? String(localized: "donation.error.api"))
        }
        return obj
    }

    // MARK: - 接口

    /// 看完激励视频后提交一次捐献，返回服务端消息。
    func submitDonation(nickname: String) async throws -> String {
        let body = ["user_id": userID, "nickname": nickname.isEmpty ? nil : nickname, "platform": "ios"] as [String: String?]
        let obj = try await request(APIConfig.donateURL, body: body)
        return obj["message"] as? String ?? ""
    }

    /// 排行榜 + 当前用户。
    func leaderboard() async throws -> (list: [DonationRanking], me: DonationRanking) {
        let obj = try await request(APIConfig.donateLeaderboardURL, body: ["user_id": userID])
        func row(_ d: [String: Any], isMe: Bool) -> DonationRanking? {
            guard let hash = d["user_id_hash"] as? String else { return nil }
            return DonationRanking(id: hash,
                                   nickname: d["nickname"] as? String ?? "",
                                   donationCount: d["donate_count"] as? Int ?? 0,
                                   isCurrentUser: isMe)
        }
        let list = (obj["leaderboard"] as? [[String: Any]] ?? []).compactMap { row($0, isMe: false) }
        let me = (obj["current_user"] as? [String: Any]).flatMap { row($0, isMe: true) }
            ?? DonationRanking(id: "me", nickname: "", donationCount: 0, isCurrentUser: true)
        return (list, me)
    }

    /// 修改昵称。
    func rename(nickname: String) async throws -> String {
        let obj = try await request(APIConfig.donateRenameURL, body: ["user_id": userID, "nickname": nickname])
        return obj["message"] as? String ?? ""
    }

    /// 概览（GET，无需鉴权）。
    func overview() async throws -> Overview {
        let (data, _) = try await client.request(APIConfig.donateOverviewURL,
                                                 userAgent: APIConfig.appUserAgent)
        return try JSONDecoder().decode(Overview.self, from: data)
    }
}
