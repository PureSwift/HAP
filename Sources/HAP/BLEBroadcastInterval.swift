/// The advertising interval of broadcast notifications for a characteristic.
///
/// - SeeAlso: HAP Specification R2, Table 7-30 Broadcast Interval
public enum BLEBroadcastInterval: UInt8, Equatable, Hashable, Sendable, CaseIterable {

    /// 20 ms (default).
    case milliseconds20 = 0x01

    /// 1280 ms.
    case milliseconds1280 = 0x02

    /// 2560 ms.
    case milliseconds2560 = 0x03

    /// The interval duration in milliseconds.
    public var milliseconds: UInt16 {
        switch self {
        case .milliseconds20: 20
        case .milliseconds1280: 1280
        case .milliseconds2560: 2560
        }
    }

    /// The default broadcast interval (20 ms).
    public static let `default` = BLEBroadcastInterval.milliseconds20
}

// MARK: -

/// Configuration properties of a characteristic's broadcast notifications.
///
/// - SeeAlso: HAP Specification R2, Table 7-29 Characteristic configuration properties
public struct BLECharacteristicConfigurationProperties: OptionSet, Equatable, Hashable, Sendable {

    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    /// Broadcast notifications are enabled for the characteristic.
    public static let broadcastNotification = BLECharacteristicConfigurationProperties(rawValue: 0x0001)
}
