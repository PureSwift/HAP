
/// Domain of a key-value store item.
///
/// - Note: Raw values match the ADK's `HAP+KeyValueStoreDomains.h`.
public struct KeyValueStoreDomain: RawRepresentable, Equatable, Hashable, Sendable {

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Static accessory provisioning data (device ID, long-term keys, setup info).
    public static let provisioning = KeyValueStoreDomain(rawValue: 0x80)

    /// Accessory configuration (e.g. configuration number).
    public static let configuration = KeyValueStoreDomain(rawValue: 0x90)

    /// HomeKit characteristic configuration (e.g. broadcast notification intervals).
    public static let characteristicConfiguration = KeyValueStoreDomain(rawValue: 0x92)

    /// HomeKit pairing data.
    public static let pairings = KeyValueStoreDomain(rawValue: 0xA0)
}

// MARK: -

/// Key of a key-value store item within a domain.
public struct KeyValueStoreKey: RawRepresentable, Equatable, Hashable, Sendable {

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

// MARK: -

/// Platform key-value store for persistent accessory state.
///
/// Implementations must persist values across reboots and firmware updates (e.g. flash or
/// NVS-backed on embedded targets, file-backed on hosted platforms).
///
/// - Note: Mirrors `HAPPlatformKeyValueStore.h`.
public protocol KeyValueStore: AnyObject {

    /// Returns the value for a key, or `nil` if no value is set.
    func value(
        for key: KeyValueStoreKey,
        in domain: KeyValueStoreDomain
    ) throws(HAPError) -> Data?

    /// Sets the value for a key, replacing any existing value.
    func setValue(
        _ value: Data,
        for key: KeyValueStoreKey,
        in domain: KeyValueStoreDomain
    ) throws(HAPError)

    /// Removes the value for a key. Does nothing if no value is set.
    func removeValue(
        for key: KeyValueStoreKey,
        in domain: KeyValueStoreDomain
    ) throws(HAPError)

    /// Enumerates the keys that have values in a domain.
    ///
    /// Return `false` from `body` to stop enumerating.
    func enumerateKeys(
        in domain: KeyValueStoreDomain,
        _ body: (KeyValueStoreKey) throws(HAPError) -> Bool
    ) throws(HAPError)

    /// Removes all values in a domain.
    func removeAll(in domain: KeyValueStoreDomain) throws(HAPError)
}
