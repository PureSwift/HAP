import FoundationEmbedded
@testable import HAP

/// In-memory key-value store for tests.
final class MockKeyValueStore: KeyValueStore {

    private var storage: [KeyValueStoreDomain: [KeyValueStoreKey: Data]] = [:]

    /// When set, all operations fail with this error.
    var failure: HAPError?

    func value(
        for key: KeyValueStoreKey,
        in domain: KeyValueStoreDomain
    ) throws(HAPError) -> Data? {
        if let failure { throw failure }
        return storage[domain]?[key]
    }

    func setValue(
        _ value: Data,
        for key: KeyValueStoreKey,
        in domain: KeyValueStoreDomain
    ) throws(HAPError) {
        if let failure { throw failure }
        storage[domain, default: [:]][key] = value
    }

    func removeValue(
        for key: KeyValueStoreKey,
        in domain: KeyValueStoreDomain
    ) throws(HAPError) {
        if let failure { throw failure }
        storage[domain]?[key] = nil
    }

    func enumerateKeys(
        in domain: KeyValueStoreDomain,
        _ body: (KeyValueStoreKey) throws(HAPError) -> Bool
    ) throws(HAPError) {
        if let failure { throw failure }
        for key in (storage[domain] ?? [:]).keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard try body(key) else { return }
        }
    }

    func removeAll(in domain: KeyValueStoreDomain) throws(HAPError) {
        if let failure { throw failure }
        storage[domain] = nil
    }
}
