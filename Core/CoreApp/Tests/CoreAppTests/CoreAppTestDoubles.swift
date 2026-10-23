import Foundation
import Security
import Synchronization
@testable import CoreApp

/// In-memory Keychain keyed by account. Each `force…` status makes the matching
/// call fail, so the error paths can be exercised without the real Keychain.
final class FakeKeychainBackend: KeychainBackend {
    struct State {
        var items: [String: Data] = [:]
        var forcedUpdateStatus: OSStatus?
        var forcedAddStatus: OSStatus?
        var forcedCopyStatus: OSStatus?
        var forcedCopyResult: AnyObject?
        var forcedDeleteStatus: OSStatus?
    }

    private let state = Mutex(State())

    func configure(_ change: (inout State) -> Void) {
        state.withLock { change(&$0) }
    }

    func item(_ account: String) -> Data? {
        state.withLock { $0.items[account] }
    }

    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        let account = query[kSecAttrAccount as String] as! String
        return state.withLock {
            if let status = $0.forcedUpdateStatus { return status }
            guard $0.items[account] != nil else { return errSecItemNotFound }
            $0.items[account] = attributes[kSecValueData as String] as? Data
            return errSecSuccess
        }
    }

    func add(_ attributes: [String: Any]) -> OSStatus {
        let account = attributes[kSecAttrAccount as String] as! String
        return state.withLock {
            if let status = $0.forcedAddStatus { return status }
            $0.items[account] = attributes[kSecValueData as String] as? Data
            return errSecSuccess
        }
    }

    func copyMatching(_ query: [String: Any]) -> (OSStatus, AnyObject?) {
        let account = query[kSecAttrAccount as String] as! String
        return state.withLock {
            if let status = $0.forcedCopyStatus { return (status, $0.forcedCopyResult) }
            guard let data = $0.items[account] else { return (errSecItemNotFound, nil) }
            return (errSecSuccess, data as AnyObject)
        }
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        let account = query[kSecAttrAccount as String] as! String
        return state.withLock {
            if let status = $0.forcedDeleteStatus { return status }
            return $0.items.removeValue(forKey: account) == nil ? errSecItemNotFound : errSecSuccess
        }
    }
}

extension UserDefaults {
    /// A throwaway suite so tests never touch `.standard` or each other.
    static func isolated() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }
}
