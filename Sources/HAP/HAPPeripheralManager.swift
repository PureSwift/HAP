import GATT

/// A GATT peripheral that additionally provides what HAP over Bluetooth LE requires.
///
/// `PeripheralManager` covers the GATT database and the connection callbacks, but HAP also
/// needs control of the advertisement payload and interval, and the ability to drop an
/// individual central. Not every stack can provide these: CoreBluetooth, for example, will
/// not broadcast manufacturer-specific data and cannot disconnect a central.
///
/// Implementations therefore declare what they genuinely support via ``supportedFeatures``
/// and emulate the rest as closely as they can. ``BLEPeripheralServer`` consults the
/// feature set so that unsupported behavior degrades predictably rather than silently.
///
/// ### Emulating on CoreBluetooth
///
/// A `DarwinPeripheral`-backed implementation should report neither
/// ``HAPPeripheralFeature/manufacturerData`` nor
/// ``HAPPeripheralFeature/centralDisconnect``, and:
///
/// - **Advertising**: ignore ``HAPAdvertisement/data`` and advertise the accessory's name
///   plus the HAP service UUID. Controllers can still discover and connect, but cannot read
///   the pairing status, global state number, or setup hash from the advertisement — so
///   disconnected and broadcast events are unavailable.
/// - **Interval**: ignore; CoreBluetooth chooses its own.
/// - **Disconnect**: invalidate the session state and stop advertising to the central; the
///   controller reconnects and re-establishes security.
public protocol HAPPeripheralManager: PeripheralManager {

    /// The capabilities this peripheral genuinely provides.
    ///
    /// Features absent from this set are emulated or ignored — see the type documentation.
    var supportedFeatures: HAPPeripheralFeature { get }

    /// Begins advertising, replacing any advertisement already being broadcast.
    ///
    /// Called whenever the accessory's advertised state changes: the pairing status, the
    /// global state number, the configuration number, or a broadcast event.
    func startAdvertising(_ advertisement: HAPAdvertisement) throws(Error)

    /// Stops advertising while remaining connectable.
    ///
    /// An accessory must not advertise while a controller is connected.
    ///
    /// - SeeAlso: HAP Specification R2, Section 7.4.1.4 Advertising Interval
    func stopAdvertising() throws(Error)

    /// Disconnects a central.
    ///
    /// Implementations that do not support ``HAPPeripheralFeature/centralDisconnect``
    /// should discard the connection's state; the controller will reconnect.
    func disconnect(_ central: Central) throws(Error)
}

// MARK: - Defaults

public extension HAPPeripheralManager {

    /// Conservative default: a stack is assumed to provide none of the HAP-specific
    /// capabilities until it declares them.
    var supportedFeatures: HAPPeripheralFeature { [] }

    /// Default: no-op, for stacks that cannot disconnect a central.
    func disconnect(_ central: Central) throws(Error) {}

    /// Whether the peripheral can advertise the data HAP requires for discovery.
    ///
    /// When `false`, controllers cannot observe the accessory's pairing status, global
    /// state number, or setup hash from the advertisement.
    var canAdvertiseAccessoryState: Bool {
        supportedFeatures.contains(.manufacturerData)
    }

    /// Whether the peripheral can broadcast events while no controller is connected.
    var canBroadcastEvents: Bool {
        supportedFeatures.contains(.encryptedNotificationAdvertisement)
            && supportedFeatures.contains(.manufacturerData)
    }
}
