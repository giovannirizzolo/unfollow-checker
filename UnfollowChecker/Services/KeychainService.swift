//
//  KeychainService.swift
//  UnfollowChecker
//

import Foundation
import Security

enum KeychainKey: String, CaseIterable {
    case sessionId = "ig.session.id"
    case csrfToken = "ig.csrf.token"
    case userId    = "ig.user.id"
    case username  = "ig.username"
    case igDid     = "ig.did"
    case mid       = "ig.mid"
    case rur       = "ig.rur"
}

enum KeychainService {
    static func save(_ value: String, for key: KeychainKey) throws {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrAccount:     key.rawValue,
            kSecValueData:       data,
            kSecAttrAccessible:  kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess { throw KeychainError.saveFailed(status) }
    }

    static func load(for key: KeychainKey) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
            kSecReturnData:  kCFBooleanTrue as Any,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(for key: KeychainKey) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func clearAll() {
        KeychainKey.allCases.forEach { delete(for: $0) }
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
}
