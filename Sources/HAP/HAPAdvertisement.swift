/// A HAP Bluetooth LE advertisement to broadcast.
///
/// Carries the complete advertising data — the Flags AD structure followed by the
/// Manufacturer Data AD structure — along with the interval the accessory requests and the
/// name to place in the scan response.
///
/// - SeeAlso: HAP Specification R2, Section 7.4.2 HAP BLE Advertisement Formats
public struct HAPAdvertisement: Equatable, Hashable, Sendable {

    /// The complete advertising data (AD structures).
    ///
    /// Stacks that cannot broadcast manufacturer-specific data — notably CoreBluetooth —
    /// cannot honor this. See ``HAPPeripheralFeature/manufacturerData``.
    public var data: Data

    /// The requested advertising interval.
    ///
    /// Stacks that do not expose interval control ignore this.
    /// See ``HAPPeripheralFeature/advertisingInterval``.
    public var interval: BLEAdvertisingInterval

    /// The accessory name, for the scan response.
    public var localName: String?

    /// Whether this is an encrypted notification advertisement rather than a regular one.
    ///
    /// Encrypted notification advertisements carry a broadcast event and are only
    /// meaningful on stacks that support ``HAPPeripheralFeature/manufacturerData``.
    public var isEncryptedNotification: Bool

    public init(
        data: Data,
        interval: BLEAdvertisingInterval = .minimum,
        localName: String? = nil,
        isEncryptedNotification: Bool = false
    ) {
        self.data = data
        self.interval = interval
        self.localName = localName
        self.isEncryptedNotification = isEncryptedNotification
    }
}

// MARK: -

/// Capabilities a ``HAPPeripheralManager`` may or may not provide.
///
/// HAP requires behavior that some Bluetooth stacks cannot express. A peripheral reports
/// what it genuinely supports so the accessory server can degrade predictably instead of
/// silently misbehaving.
public struct HAPPeripheralFeature: OptionSet, Equatable, Hashable, Sendable {

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// The stack can broadcast custom manufacturer-specific advertising data.
    ///
    /// Required for controllers to discover an unpaired accessory, to observe the global
    /// state number, and to match a scanned setup payload by setup hash.
    ///
    /// - Note: CoreBluetooth cannot do this — a peripheral may only advertise a local name
    ///   and service UUIDs. A Darwin implementation should omit this feature and advertise
    ///   the HAP service UUID plus the accessory name instead.
    public static let manufacturerData = HAPPeripheralFeature(rawValue: 1 << 0)

    /// The stack allows the advertising interval to be configured.
    ///
    /// - Note: CoreBluetooth does not expose interval control.
    public static let advertisingInterval = HAPPeripheralFeature(rawValue: 1 << 1)

    /// The peripheral can disconnect an individual central.
    ///
    /// HAP requires tearing down a connection whose session failed, and disconnecting a
    /// controller whose pairing was removed.
    ///
    /// - Note: CoreBluetooth peripherals cannot disconnect a central. Implementations
    ///   without this feature should invalidate their session state and let the controller
    ///   time out or reconnect.
    public static let centralDisconnect = HAPPeripheralFeature(rawValue: 1 << 2)

    /// The stack can broadcast encrypted notification advertisements while disconnected.
    ///
    /// Requires ``manufacturerData``.
    public static let encryptedNotificationAdvertisement = HAPPeripheralFeature(rawValue: 1 << 3)

    /// Everything HAP asks for — a stack with full control of the link layer.
    public static let all: HAPPeripheralFeature = [
        .manufacturerData,
        .advertisingInterval,
        .centralDisconnect,
        .encryptedNotificationAdvertisement
    ]
}
