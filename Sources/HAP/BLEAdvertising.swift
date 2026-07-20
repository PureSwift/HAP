
/// The Global State Number (GSN) for a Bluetooth LE accessory server.
///
/// The GSN represents the state at which a required change on the accessory was last notified
/// to the controller. It is a 16-bit monotonically increasing value in the range 1 – 65535 that
/// wraps to 1 on overflow, persists across reboots and power cycles, and is reset to 1 on
/// factory reset or firmware update.
///
/// - SeeAlso: HAP Specification R2, Section 7.4.1.8 Global State Number (GSN)
/// - Note: Corresponds to the C `HAPBLEAccessoryServerGSN` struct.
public struct BLEAccessoryServerGSN: Equatable, Hashable, Sendable {

    /// Global State Number.
    public private(set) var gsn: UInt16

    /// Whether the GSN has been incremented in the current connect / disconnect cycle.
    public private(set) var didIncrement: Bool

    /// The initial state of a factory-reset accessory.
    public static let initial = BLEAccessoryServerGSN()

    public init() {
        self.gsn = 1
        self.didIncrement = false
    }

    /// Creates a state from persisted values.
    ///
    /// - Returns: `nil` if the global state number is 0, which is out of range.
    public init?(gsn: UInt16, didIncrement: Bool) {
        guard gsn != 0 else { return nil }
        self.gsn = gsn
        self.didIncrement = didIncrement
    }

    /// Increments the global state number, at most once per connect / disconnect cycle.
    ///
    /// Wraps to 1 on overflow, since 0 is not a valid value.
    ///
    /// - Returns: Whether the value changed.
    @discardableResult
    public mutating func increment() -> Bool {
        guard !didIncrement else { return false }
        gsn = gsn == .max ? 1 : gsn + 1
        didIncrement = true
        return true
    }

    /// Allows the global state number to be incremented again.
    ///
    /// Called when a controller disconnects, ending the current connect / disconnect cycle.
    public mutating func endCycle() {
        didIncrement = false
    }
}

// MARK: -

/// Status flags embedded in the SF byte of a HAP BLE Regular Advertisement.
///
/// - SeeAlso: HAP Specification R14, Section 7.4.2.1.2 Manufacturer Data
public struct BLEStatusFlags: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Accessory is not yet paired with any controller.
    ///
    /// When this flag is clear the accessory is paired.
    public static let notPaired = Self(rawValue: 1 << 0)
}

// MARK: -

/// Manufacturer data for the HAP BLE Regular Advertisement Format.
///
/// Broadcast while no broadcast event is pending. Contains identity and state fields that
/// allow controllers to detect pairing eligibility and state changes without connecting.
///
/// - SeeAlso: HAP Specification R14, Section 7.4.2.1.2 Manufacturer Data
public struct BLERegularManufacturerData {
    /// Apple's Bluetooth company ID (always `0x004C`).
    public static let companyID: UInt16 = 0x004C

    /// HAP BLE Regular Advertisement type byte (always `0x06`).
    public static let type: UInt8 = 0x06

    /// Accessory status flags (SF byte).
    public var statusFlags: BLEStatusFlags

    /// Device ID — a 6-byte identifier, typically derived from the BLE MAC address.
    public var deviceID: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    /// Accessory Category ID (ACID).
    public var accessoryCategory: AccessoryCategory

    /// Global State Number (GSN) — incremented on each state change while disconnected.
    public var globalStateNumber: UInt16

    /// Configuration Number (CN) — incremented when the HAP attribute database changes.
    public var configurationNumber: UInt8

    /// HAP BLE Compatible Version (CV). Always `0x02`.
    public static let compatibleVersion: UInt8 = 0x02

    /// Setup hash (SH) — first 4 bytes of SHA-512(Setup ID ‖ Device ID string).
    ///
    /// Present only when a Setup ID is available on the accessory.
    ///
    /// - SeeAlso: HAP Specification R14, Section 7.4.2.1.2 Manufacturer Data
    public var setupHash: (UInt8, UInt8, UInt8, UInt8)?
}

// MARK: -

/// Manufacturer data for the HAP BLE Encrypted Notification Advertisement Format.
///
/// Broadcast when a characteristic value changes while no controller is connected and the
/// characteristic supports broadcast notifications. The payload is encrypted with
/// ChaCha20-Poly1305 using the broadcast encryption key.
///
/// - SeeAlso: HAP Specification R14, Section 7.4.2.2.2 Manufacturer Data
public struct BLEEncryptedNotificationManufacturerData {
    /// Apple's Bluetooth company ID (always `0x004C`).
    public static let companyID: UInt16 = 0x004C

    /// HAP BLE Encrypted Notification Advertisement type byte (always `0x11`).
    public static let type: UInt8 = 0x11

    /// Advertising ID — a 6-byte identifier derived from the broadcast encryption key.
    public var advertisingID: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    /// Global State Number (GSN) — used as the ChaCha20-Poly1305 nonce.
    public var globalStateNumber: UInt16

    /// Instance ID (IID) of the characteristic whose value changed.
    public var characteristicIID: UInt16

    /// Characteristic value (always 8 bytes, zero-padded).
    public var value: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    /// First 4 bytes of the ChaCha20-Poly1305 authentication tag.
    public var authTag: (UInt8, UInt8, UInt8, UInt8)
}

// MARK: -

/// The advertisement format produced by `HAPBLEAccessoryServerGetAdvertisingParameters`.
///
/// - SeeAlso: HAP Specification R14, Section 7.4.2
public enum BLEAdvertisementFormat {
    /// HAP BLE Regular Advertisement Format.
    ///
    /// Used during normal operation. The advertising interval is 20 ms for the first 30 s
    /// after boot or 3 s after a disconnected event, then falls back to the configured
    /// ``BluetoothAccessoryServer/preferredAdvertisingInterval``.
    ///
    /// - SeeAlso: HAP Specification R14, Section 7.4.2.1
    case regular(BLERegularManufacturerData)

    /// HAP BLE Encrypted Notification Advertisement Format.
    ///
    /// Used when a characteristic value changes while no controller is connected.
    /// The advertising interval is one of 20 ms, 1280 ms, or 2560 ms, as configured
    /// per characteristic.
    ///
    /// - SeeAlso: HAP Specification R14, Section 7.4.2.2
    case encryptedNotification(BLEEncryptedNotificationManufacturerData)
}

// MARK: -

/// Parameters for a Bluetooth LE advertisement.
///
/// `nil` when advertising should not be active (e.g. while a controller is connected —
/// the accessory must not advertise during an active connection).
///
/// - SeeAlso: HAP Specification R14, Section 7.4.1.4 Advertising Interval
public struct BLEAdvertisingParameters {
    /// Advertising interval.
    public var advertisingInterval: BLEAdvertisingInterval

    /// The typed advertisement format and its manufacturer data payload.
    public var format: BLEAdvertisementFormat

    /// Name to include in the scan response when the full name doesn't fit in the advertising data.
    ///
    /// `nil` when the complete name fits in the primary advertising payload.
    public var scanResponseName: String?
}
