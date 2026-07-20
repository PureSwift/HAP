/// A Bluetooth LE advertising interval.
///
/// The raw value is in units of 0.625 ms, as defined by the Bluetooth Core Specification
/// (Vol 2 Part E Section 7.8.5 LE Set Advertising Parameters Command).
///
/// Use ``init(milliseconds:)`` to construct a value from a human-readable duration.
///
/// - Note: Corresponds to the C `HAPBLEAdvertisingInterval` type (`uint16_t`).
public struct BLEAdvertisingInterval: RawRepresentable, Equatable, Comparable {
    /// Raw value in units of 0.625 ms.
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    /// Creates an advertising interval from a value in milliseconds.
    ///
    /// - Parameter milliseconds: The interval duration in milliseconds.
    public init(milliseconds: Double) {
        self.rawValue = UInt16(milliseconds / 0.625)
    }

    /// The interval duration in milliseconds.
    public var milliseconds: Double {
        Double(rawValue) * 0.625
    }

    // MARK: Constants

    /// Minimum supported advertising interval (160 ms).
    public static let minimum = Self(milliseconds: 160)

    /// Maximum supported advertising interval (2500 ms).
    public static let maximum = Self(milliseconds: 2500)

    /// Minimum duration for broadcast and disconnected notifications (3000 ms).
    public static let minimumNotificationDuration = Self(milliseconds: 3000)

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: -

/// Configuration for running a HomeKit accessory server over Bluetooth LE.
///
/// - SeeAlso: HAP Specification R14, Section 7.4.1.4 Advertising Interval
/// - SeeAlso: Accessory Design Guidelines for Apple Devices R7, Section 11.5 Advertising Interval
public struct BluetoothAccessoryServer {
    /// Preferred regular advertising interval.
    ///
    /// Must be in the range `BLEAdvertisingInterval.minimum` … `BLEAdvertisingInterval.maximum`.
    ///
    /// Preferred values:
    /// - 211.25 ms, 318.75 ms, 417.5 ms, 546.25 ms (mains-powered or large battery)
    /// - 760 ms, 852.5 ms, 1022.5 ms, 1285 ms (battery-powered with no controllable characteristics)
    ///
    /// Longer intervals result in longer discovery and connection times.
    public var preferredAdvertisingInterval: BLEAdvertisingInterval

    /// Preferred duration of broadcast and disconnected event notifications.
    ///
    /// Must be at least `BLEAdvertisingInterval.minimumNotificationDuration` (3000 ms).
    public var preferredNotificationDuration: BLEAdvertisingInterval

    public init(
        preferredAdvertisingInterval: BLEAdvertisingInterval = .minimum,
        preferredNotificationDuration: BLEAdvertisingInterval = .minimumNotificationDuration
    ) {
        self.preferredAdvertisingInterval = preferredAdvertisingInterval
        self.preferredNotificationDuration = preferredNotificationDuration
    }
}
