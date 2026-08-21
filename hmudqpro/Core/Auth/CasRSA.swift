import Foundation
import BigInt

/// 哈医大大庆校区 webvpn CAS 登录的 RSA 密码加密（从 v1 移植）。
///
/// 流程（学校 2026 年 CAS 升级后必需）：
///   1. 密码反转："abc123" → "321cba"
///   2. 公钥从 CAS `/v2/getPubKey` 获取，返回 {modulus, exponent} hex
///   3. 正方 security.js 风格的"裸 RSA"（无 PKCS padding）：
///      密码转 charCode → 每 2 字节小端合成 16 位整数 → 分块 → powMod
///   4. 密文 hex 左补零到 modulus 长度，空格连接，填入表单 password 字段
///
/// Apple SecKey/CryptoKit 不支持无 padding + 自定义分块，故用 BigInt 实现 powMod。
enum CasRSA {
    enum RSAError: Error, LocalizedError {
        case invalidModulus
        case invalidExponent
        var errorDescription: String? {
            switch self {
            case .invalidModulus: return "CAS 公钥 modulus 解析失败"
            case .invalidExponent: return "CAS 公钥 exponent 解析失败"
            }
        }
    }

    /// 正方 CAS 裸 RSA 加密（密码自动先反转）。
    static func encrypt(password: String, modulusHex: String, exponentHex: String) throws -> String {
        let reversed = String(password.reversed())

        guard let modulus = BigInt(modulusHex, radix: 16) else { throw RSAError.invalidModulus }
        guard let exponent = BigInt(exponentHex, radix: 16) else { throw RSAError.invalidExponent }

        // chunkSize = 2 * biHighIndex(modulus)，biHighIndex 基于 16 位 digit（见 security.js）
        let bitLength = modulus.bitWidth
        let digitCount = (bitLength + 15) / 16
        let chunkSize = 2 * max(0, digitCount - 1)

        // 模拟 JS charCodeAt（取 UTF-16 码点；密码均为常见 ASCII）
        var codes: [Int] = reversed.unicodeScalars.map { Int($0.value) }
        while codes.count % chunkSize != 0 { codes.append(0) }

        var blocks: [String] = []
        var i = 0
        while i < codes.count {
            var block = BigInt(0)
            var k = i
            var j = 0
            while k < i + chunkSize {
                var word = codes[k]
                k += 1
                if k < i + chunkSize {
                    word += codes[k] << 8
                    k += 1
                }
                block += BigInt(word) << (16 * j)
                j += 1
            }
            let crypt = block.power(exponent, modulus: modulus)
            var hex = String(crypt, radix: 16).lowercased()
            while hex.count < modulusHex.count { hex = "0" + hex }
            blocks.append(hex)
            i += chunkSize
        }
        return blocks.joined(separator: " ")
    }
}
