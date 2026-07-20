/// Broadcast notification configuration of a single characteristic.
public struct BLEBroadcastConfiguration: Equatable, Hashable, Sendable {

    /// Whether broadcast notifications are enabled.
    public var isEnabled: Bool

    /// The broadcast advertising interval.
    public var interval: BLEBroadcastInterval

    public init(isEnabled: Bool = false, interval: BLEBroadcastInterval = .default) {
        self.isEnabled = isEnabled
        self.interval = interval
    }
}

// MARK: -

/// Server state consulted by the BLE configuration procedures.
///
/// The characteristic configuration procedure reads and updates the per-characteristic
/// broadcast configuration; the protocol configuration procedure reads the accessory-wide
/// state and generates broadcast encryption keys for the requesting session.
public protocol BLEConfigurationContext {

    /// The broadcast configuration of a characteristic.
    func broadcastConfiguration(
        for characteristic: UInt64
    ) throws(HAPError) -> BLEBroadcastConfiguration

    /// Updates the broadcast configuration of a characteristic.
    mutating func setBroadcastConfiguration(
        _ configuration: BLEBroadcastConfiguration,
        for characteristic: UInt64
    ) throws(HAPError)

    /// The current global state number.
    var globalStateNumber: UInt16 { get }

    /// The current configuration number.
    var configurationNumber: UInt8 { get }

    /// The 6-byte advertising identifier used in encrypted notification advertisements
    /// (typically the accessory's device ID).
    var advertisingIdentifier: Data { get }

    /// Generates (or refreshes) the broadcast encryption key for the verified session
    /// and returns the 32-byte key.
    ///
    /// - SeeAlso: HAP Specification R2, Section 7.4.7.3 Broadcast Encryption Key Generation
    mutating func generateBroadcastEncryptionKey() throws(HAPError) -> Data

    /// Stores a new advertising identifier.
    mutating func setAdvertisingIdentifier(_ identifier: Data) throws(HAPError)
}
