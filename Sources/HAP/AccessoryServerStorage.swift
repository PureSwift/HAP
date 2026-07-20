/// Keys of the accessory server's configuration domain values.
///
/// - Note: Raw values match the ADK's `HAP+KeyValueStoreDomains.h`.
enum AccessoryServerStorageKey {
    static let deviceID = KeyValueStoreKey(rawValue: 0x00)
    static let configurationNumber = KeyValueStoreKey(rawValue: 0x20)
    static let longTermSecretKey = KeyValueStoreKey(rawValue: 0x21)
    static let bleGSN = KeyValueStoreKey(rawValue: 0x40)
    static let bleBroadcastParameters = KeyValueStoreKey(rawValue: 0x41)
}

/// Persistent accessory server state, backed by a platform ``KeyValueStore``.
///
/// Stores the accessory's identity and protocol state in the
/// ``KeyValueStoreDomain/configuration`` domain using the ADK-compatible key layout:
/// device ID (0x00), configuration number (0x20), long-term secret key (0x21),
/// BLE global state number (0x40), and BLE broadcast parameters (0x41).
///
/// Identity values are generated on first access and persist across reboots.
public final class AccessoryServerStorage<Store: KeyValueStore, Random: RandomNumberSource> {

    private let store: Store
    private var random: Random

    public init(store: Store, random: Random) {
        self.store = store
        self.random = random
    }

    // MARK: Identity

    /// The accessory's 6-byte device ID, generated randomly on first access.
    ///
    /// - SeeAlso: HAP Specification R2, Section 5.4 Device ID
    public func deviceID() throws(HAPError) -> Data {
        if let existing = try store.value(for: AccessoryServerStorageKey.deviceID, in: .configuration),
           existing.count == 6 {
            return existing
        }
        let generated = random.randomData(count: 6)
        try store.setValue(generated, for: AccessoryServerStorageKey.deviceID, in: .configuration)
        return generated
    }

    /// The device ID formatted as a pairing identifier, e.g. `"1A:2B:3C:4D:5E:6F"`.
    public func deviceIDString() throws(HAPError) -> String {
        let bytes = Array(try deviceID())
        return bytes.map { byte in
            let hex = String(byte, radix: 16, uppercase: true)
            return byte < 0x10 ? "0" + hex : hex
        }.joined(separator: ":")
    }

    /// The accessory's Ed25519 long-term secret key, generated on first access.
    public func longTermSecretKey<Crypto: CryptoProvider>(
        using crypto: Crypto
    ) throws(HAPError) -> Data {
        if let existing = try store.value(for: AccessoryServerStorageKey.longTermSecretKey, in: .configuration),
           existing.count == 32 {
            return existing
        }
        let generated = crypto.makeEd25519PrivateKey()
        try store.setValue(generated, for: AccessoryServerStorageKey.longTermSecretKey, in: .configuration)
        return generated
    }

    // MARK: Configuration Number

    /// The configuration number (`c#` / CN), starting at 1.
    ///
    /// Must be incremented after a firmware update or attribute database change,
    /// wrapping from 255 to 1.
    public func configurationNumber() throws(HAPError) -> UInt8 {
        guard let data = try store.value(for: AccessoryServerStorageKey.configurationNumber, in: .configuration),
              let value = Array(data).first, value != 0
        else { return 1 }
        return value
    }

    /// Increments the configuration number, wrapping from 255 to 1.
    public func incrementConfigurationNumber() throws(HAPError) {
        let current = try configurationNumber()
        let next: UInt8 = current == .max ? 1 : current + 1
        try store.setValue(Data([next]), for: AccessoryServerStorageKey.configurationNumber, in: .configuration)
    }

    // MARK: BLE Global State Number

    /// The persisted global state number, `.initial` when none is stored.
    public func globalStateNumber() throws(HAPError) -> BLEAccessoryServerGSN {
        guard let data = try store.value(for: AccessoryServerStorageKey.bleGSN, in: .configuration),
              data.count == 3
        else { return .initial }
        let bytes = Array(data)
        let value = UInt16(bytes[0]) | UInt16(bytes[1]) << 8
        return BLEAccessoryServerGSN(gsn: value, didIncrement: bytes[2] == 1) ?? .initial
    }

    /// Persists the global state number.
    public func setGlobalStateNumber(_ gsn: BLEAccessoryServerGSN) throws(HAPError) {
        var bytes = littleEndianBytes(gsn.gsn)
        bytes.append(gsn.didIncrement ? 1 : 0)
        try store.setValue(Data(bytes), for: AccessoryServerStorageKey.bleGSN, in: .configuration)
    }

    // MARK: BLE Broadcast Parameters

    /// The persisted broadcast parameters, empty when none are stored.
    public func broadcastParameters() throws(HAPError) -> BLEBroadcastParameters {
        guard let data = try store.value(for: AccessoryServerStorageKey.bleBroadcastParameters, in: .configuration),
              let parameters = BLEBroadcastParameters(storageData: data)
        else { return BLEBroadcastParameters() }
        return parameters
    }

    /// Persists the broadcast parameters.
    public func setBroadcastParameters(_ parameters: BLEBroadcastParameters) throws(HAPError) {
        try store.setValue(
            parameters.storageData,
            for: AccessoryServerStorageKey.bleBroadcastParameters,
            in: .configuration
        )
    }

    // MARK: Factory Reset

    /// Removes all pairings and protocol state, keeping the accessory's identity.
    ///
    /// The global state number and broadcast parameters are reset; the device ID and
    /// long-term keys are preserved per the ADK's factory reset behavior.
    public func removePairingState() throws(HAPError) {
        try store.removeAll(in: .pairings)
        try store.removeValue(for: AccessoryServerStorageKey.bleGSN, in: .configuration)
        try store.removeValue(for: AccessoryServerStorageKey.bleBroadcastParameters, in: .configuration)
    }
}
