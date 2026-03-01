/// Properties that HomeKit characteristics can have.
///
/// For Apple-defined characteristics, the default values for the following properties are defined by the specification:
/// - ``readable`` (Paired Read)
/// - ``writable`` (Paired Write)
/// - ``supportsEventNotification`` (Notify)
///
/// The remaining properties must be evaluated on a case-by-case basis.
///
/// - Note: ABI-compatible with the C `HAPCharacteristicProperties` struct (`sizeof == 4`).
public struct CharacteristicProperties: OptionSet {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    // MARK: - General

    /// The characteristic is readable.
    ///
    /// A read handler must be provided. Only controllers with a secured connection can perform reads.
    public static let readable = Self(rawValue: 1 << 0)

    /// The characteristic is writable.
    ///
    /// A write handler must be provided. Only controllers with a secured connection can perform writes.
    public static let writable = Self(rawValue: 1 << 1)

    /// The characteristic supports event notifications over the event connection established by the controller.
    ///
    /// A read handler must be provided. Only controllers with a secured connection can subscribe.
    /// Raise events by calling `HAPAccessoryServerRaiseEvent` or `HAPAccessoryServerRaiseEventOnSession`.
    public static let supportsEventNotification = Self(rawValue: 1 << 2)

    /// The characteristic should be hidden from the user.
    ///
    /// Generic HomeKit applications won't show these characteristics.
    /// When all characteristics in a service are hidden, the service must also be marked hidden.
    public static let hidden = Self(rawValue: 1 << 3)

    /// The characteristic will only be accessible by admin controllers.
    ///
    /// - Warning: Deprecated. Use ``readRequiresAdminPermissions`` and ``writeRequiresAdminPermissions`` instead.
    @available(*, deprecated, renamed: "readRequiresAdminPermissions")
    public static let requiresAdminPermissions = Self(rawValue: 1 << 4)

    /// Reads (and event notifications) are only delivered to controllers with admin permissions.
    public static let readRequiresAdminPermissions = Self(rawValue: 1 << 5)

    /// Writes are only executed if the controller has admin permissions.
    public static let writeRequiresAdminPermissions = Self(rawValue: 1 << 6)

    /// The characteristic requires time-sensitive actions (timed write).
    ///
    /// Writes execute only if the accessory can be reached within a short time frame.
    /// The characteristic must also be marked ``writable``.
    public static let requiresTimedWrite = Self(rawValue: 1 << 7)

    /// The characteristic requires additional authorization data on write.
    ///
    /// The write handler is responsible for validating the data; return `kHAPError_NotAuthorized` if insufficient.
    /// The characteristic must also be marked ``writable``.
    public static let supportsAuthorizationData = Self(rawValue: 1 << 8)

    // MARK: - IP-only (Ethernet / Wi-Fi)

    /// Prevents the characteristic from being read during IP discovery.
    ///
    /// A `null` value is sent to the controller during discovery; only explicit reads are processed.
    /// Useful for characteristics that manage state across multiple read/write cycles (e.g. firmware update).
    public static let ipControlPoint = Self(rawValue: 1 << 9)

    /// Write operations on the characteristic require a read-response value (IP only).
    ///
    /// After a successful write, a read is always requested immediately.
    /// Both read and write handlers must be provided. The characteristic must also be marked ``writable``.
    public static let ipSupportsWriteResponse = Self(rawValue: 1 << 10)

    // MARK: - BLE-only (Bluetooth LE)

    /// The characteristic supports broadcast notifications when no controller is connected (BLE only).
    ///
    /// A read handler must be provided. Only paired controllers can decode the broadcasts.
    /// Raise events by calling `HAPAccessoryServerRaiseEvent` or `HAPAccessoryServerRaiseEventOnSession`.
    public static let bleSupportsBroadcastNotification = Self(rawValue: 1 << 11)

    /// State changes trigger a reconnect so paired controllers can fetch the updated value (BLE only).
    ///
    /// Requires ``readable``, ``supportsEventNotification``, and ``bleSupportsBroadcastNotification``.
    /// Use only for important state changes (e.g. contact sensor, door state) — not for frequent readings.
    public static let bleSupportsDisconnectedNotification = Self(rawValue: 1 << 12)

    /// The characteristic is readable even before a secured session is established (BLE only).
    ///
    /// Primarily an internal property used by pairing characteristics.
    public static let bleReadableWithoutSecurity = Self(rawValue: 1 << 13)

    /// The characteristic is writable even before a secured session is established (BLE only).
    ///
    /// Primarily an internal property used by pairing characteristics.
    public static let bleWritableWithoutSecurity = Self(rawValue: 1 << 14)
}
