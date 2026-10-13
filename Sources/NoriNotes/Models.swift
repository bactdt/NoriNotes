import Foundation
import CryptoKit
import SwiftUI
import Security

struct Note: Identifiable, Codable {
    let id: UUID
    var title: String
    var body: String
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var isArchived: Bool
    var isLocked: Bool
    var protection: ProtectedNotePayload?

    var isProtected: Bool { protection != nil }
    var displayTitle: String { isLocked ? "受保护笔记" : (title.isEmpty ? "无标题笔记" : title) }

    /// 兼容旧版 notebook.json（无 tags/pin/archive/lock/protection 字段），
    /// 缺失字段给默认值而不是走损坏备份路径，避免升级丢数据。
    private enum CodingKeys: String, CodingKey {
        case id, title, body, tags, createdAt, updatedAt
        case isPinned, isArchived, isLocked, protection
    }

    init(id: UUID, title: String, body: String, tags: [String], createdAt: Date, updatedAt: Date, isPinned: Bool, isArchived: Bool, isLocked: Bool, protection: ProtectedNotePayload?) {
        self.id = id
        self.title = title
        self.body = body
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.isLocked = isLocked
        self.protection = protection
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        protection = try container.decodeIfPresent(ProtectedNotePayload.self, forKey: .protection)
    }
}

struct ProtectedNotePayload: Codable, Equatable {
    var salt: String
    var combined: String
}

struct SecureNoteContent: Codable {
    var title: String
    var body: String
    var tags: [String]
}

enum NoteCryptoError: Error {
    case malformedPayload
    case authenticationFailed
}

/// 密码学实现为冻结状态（技术债 TD-1）：改动前必须征得用户确认。
/// 结构：PBKDF2-HMAC-SHA256（160k 轮）派生密钥 + AES-GCM 认证加密。
enum NoteCrypto {
    private static let rounds = 160_000

    static func protect(_ content: SecureNoteContent, password: String) throws -> (ProtectedNotePayload, Data) {
        var salt = [UInt8](repeating: 0, count: 16)
        let randomStatus = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }
        guard randomStatus == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(randomStatus)) }
        let saltData = Data(salt)
        let key = deriveKey(password: password, salt: saltData)
        let payload = try JSONEncoder().encode(content)
        let box = try AES.GCM.seal(payload, using: SymmetricKey(data: key))
        guard let combined = box.combined else { throw NoteCryptoError.malformedPayload }
        return (ProtectedNotePayload(salt: saltData.base64EncodedString(), combined: combined.base64EncodedString()), key)
    }

    static func unlock(_ payload: ProtectedNotePayload, password: String) throws -> (SecureNoteContent, Data) {
        guard let salt = Data(base64Encoded: payload.salt),
              let combined = Data(base64Encoded: payload.combined),
              let box = try? AES.GCM.SealedBox(combined: combined) else {
            throw NoteCryptoError.malformedPayload
        }
        let key = deriveKey(password: password, salt: salt)
        let cleartext: Data
        do {
            cleartext = try AES.GCM.open(box, using: SymmetricKey(data: key))
        } catch {
            throw NoteCryptoError.authenticationFailed
        }
        return (try JSONDecoder().decode(SecureNoteContent.self, from: cleartext), key)
    }

    static func reseal(_ content: SecureNoteContent, using key: Data) throws -> String {
        let bytes = try JSONEncoder().encode(content)
        let box = try AES.GCM.seal(bytes, using: SymmetricKey(data: key))
        guard let combined = box.combined else { throw NoteCryptoError.malformedPayload }
        return combined.base64EncodedString()
    }

    private static func deriveKey(password: String, salt: Data) -> Data {
        let passwordKey = SymmetricKey(data: Data(password.utf8))
        let saltAndBlock = salt + Data([0, 0, 0, 1])
        var u = Data(HMAC<SHA256>.authenticationCode(for: saltAndBlock, using: passwordKey))
        var accumulator = [UInt8](u)
        if rounds > 1 {
            for _ in 1..<rounds {
                u = Data(HMAC<SHA256>.authenticationCode(for: u, using: passwordKey))
                let bytes = [UInt8](u)
                for index in accumulator.indices { accumulator[index] ^= bytes[index] }
            }
        }
        return Data(accumulator)
    }
}

enum NotebookFilter: Hashable {
    case all
    case pinned
    case archive
    case tag(String)
}

enum AppTheme: String, CaseIterable, Identifiable {
    case parchment = "羊皮纸"
    case seaGlass = "海盐蓝"
    case sage = "鼠尾草"
    case dusk = "暮色"

    var id: String { rawValue }

    var palette: ThemePalette {
        switch self {
        case .parchment:
            ThemePalette(canvas: Color(red: 0.965, green: 0.949, blue: 0.914), panel: Color(red: 0.991, green: 0.982, blue: 0.960), ink: Color(red: 0.20, green: 0.22, blue: 0.21), muted: Color(red: 0.48, green: 0.49, blue: 0.45), accent: Color(red: 0.73, green: 0.36, blue: 0.22), border: Color(red: 0.88, green: 0.86, blue: 0.81), dark: false)
        case .seaGlass:
            ThemePalette(canvas: Color(red: 0.91, green: 0.95, blue: 0.95), panel: Color(red: 0.97, green: 0.99, blue: 0.985), ink: Color(red: 0.15, green: 0.24, blue: 0.26), muted: Color(red: 0.39, green: 0.51, blue: 0.53), accent: Color(red: 0.18, green: 0.48, blue: 0.52), border: Color(red: 0.81, green: 0.87, blue: 0.87), dark: false)
        case .sage:
            ThemePalette(canvas: Color(red: 0.92, green: 0.94, blue: 0.88), panel: Color(red: 0.98, green: 0.985, blue: 0.95), ink: Color(red: 0.22, green: 0.26, blue: 0.20), muted: Color(red: 0.45, green: 0.50, blue: 0.42), accent: Color(red: 0.35, green: 0.48, blue: 0.30), border: Color(red: 0.83, green: 0.87, blue: 0.77), dark: false)
        case .dusk:
            ThemePalette(canvas: Color(red: 0.105, green: 0.12, blue: 0.14), panel: Color(red: 0.15, green: 0.17, blue: 0.19), ink: Color(red: 0.91, green: 0.91, blue: 0.88), muted: Color(red: 0.60, green: 0.63, blue: 0.63), accent: Color(red: 0.92, green: 0.59, blue: 0.40), border: Color(red: 0.25, green: 0.28, blue: 0.29), dark: true)
        }
    }
}

struct ThemePalette {
    let canvas: Color
    let panel: Color
    let ink: Color
    let muted: Color
    let accent: Color
    let border: Color
    let dark: Bool

    /// SwiftUI Color 无法直接比较；用 RGBA 分量近似判等，
    /// 供编辑器 Coordinator 判断"主题真的变了"才全文重样式。
    func isVisuallyEqual(_ other: ThemePalette) -> Bool {
        rgba(canvas) == rgba(other.canvas)
            && rgba(panel) == rgba(other.panel)
            && rgba(ink) == rgba(other.ink)
            && rgba(muted) == rgba(other.muted)
            && rgba(accent) == rgba(other.accent)
            && rgba(border) == rgba(other.border)
            && dark == other.dark
    }

    private func rgba(_ color: Color) -> (Float, Float, Float, Float) {
        let resolved = color.resolve(in: EnvironmentValues())
        return (resolved.red, resolved.green, resolved.blue, resolved.opacity)
    }
}
