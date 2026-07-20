
/// Persistent storage of controller pairings, backed by a platform ``KeyValueStore``.
///
/// Pairings are stored in the ``KeyValueStoreDomain/pairings`` domain, one pairing per key,
/// in the ADK-compatible format (see ``Pairing/storageData``).
public final class PairingStore<Store: KeyValueStore> {

    /// The maximum number of pairings.
    ///
    /// The minimum number of pairing relationships an accessory must support is 16.
    public let capacity: Int

    private let store: Store

    public init(store: Store, capacity: Int = 16) {
        precondition(capacity >= 1)
        self.store = store
        self.capacity = capacity
    }

    /// The pairing with the given identifier, or `nil`.
    public func pairing(for identifier: String) throws(HAPError) -> Pairing? {
        try entry(for: identifier)?.pairing
    }

    /// All pairings.
    public func pairings() throws(HAPError) -> [Pairing] {
        try entries().map { $0.pairing }
    }

    /// Whether at least one controller is paired.
    public func isPaired() throws(HAPError) -> Bool {
        try !entries().isEmpty
    }

    /// Whether at least one paired controller is an admin.
    public func hasAdmin() throws(HAPError) -> Bool {
        try entries().contains { $0.pairing.isAdmin }
    }

    /// Adds a pairing, or replaces the pairing with the same identifier.
    ///
    /// - Throws: ``HAPError/outOfResources`` if the store is full.
    public func add(_ pairing: Pairing) throws(HAPError) {
        let key: KeyValueStoreKey
        if let existing = try entry(for: pairing.identifier) {
            key = existing.key
        } else if let freeKey = try freeKey() {
            key = freeKey
        } else {
            throw .outOfResources
        }
        try store.setValue(pairing.storageData, for: key, in: .pairings)
    }

    /// Removes the pairing with the given identifier. Does nothing if it does not exist.
    public func remove(_ identifier: String) throws(HAPError) {
        guard let existing = try entry(for: identifier) else { return }
        try store.removeValue(for: existing.key, in: .pairings)
    }

    /// Removes all pairings.
    public func removeAll() throws(HAPError) {
        try store.removeAll(in: .pairings)
    }
}

private extension PairingStore {

    func keys() throws(HAPError) -> [KeyValueStoreKey] {
        var keys = [KeyValueStoreKey]()
        try store.enumerateKeys(in: .pairings) { key throws(HAPError) in
            keys.append(key)
            return true
        }
        return keys
    }

    func entries() throws(HAPError) -> [(key: KeyValueStoreKey, pairing: Pairing)] {
        var entries = [(key: KeyValueStoreKey, pairing: Pairing)]()
        for key in try keys() {
            guard let data = try store.value(for: key, in: .pairings),
                  let pairing = Pairing(storageData: data)
            else { continue }
            entries.append((key, pairing))
        }
        return entries
    }

    func entry(for identifier: String) throws(HAPError) -> (key: KeyValueStoreKey, pairing: Pairing)? {
        try entries().first { $0.pairing.identifier == identifier }
    }

    func freeKey() throws(HAPError) -> KeyValueStoreKey? {
        let used = Set(try keys().map { $0.rawValue })
        guard used.count < capacity else { return nil }
        for raw in 0 ..< capacity {
            let key = UInt8(raw)
            if !used.contains(key) {
                return KeyValueStoreKey(rawValue: key)
            }
        }
        return nil
    }
}
