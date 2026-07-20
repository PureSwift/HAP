
/// A HomeKit accessory.
public struct Accessory {
    /// Accessory instance ID.
    ///
    /// - For regular accessories (IP / BLE): must be 1.
    /// - For bridged accessories: must be unique and stable across firmware updates and power cycles.
    public var aid: UInt64

    /// The category of the accessory.
    ///
    /// - For regular accessories: must match the primary service's functionality.
    /// - For bridged accessories: must be ``AccessoryCategory/bridgedAccessory``.
    public var category: AccessoryCategory

    /// The display name of the accessory.
    ///
    /// Maximum 64 characters. Avoid ':' and ';' for accessories that support Bluetooth LE.
    /// The user may adjust the name on the controller; such changes are local only.
    public var name: String

    /// The manufacturer of the accessory. Maximum 64 characters.
    public var manufacturer: String

    /// The model name of the accessory. 1–64 characters.
    public var model: String

    /// The serial number of the accessory. 2–64 characters.
    public var serialNumber: String

    /// The firmware version string. Format: `x[.y[.z]]` (e.g. `"100.1.1"`). Maximum 64 characters.
    public var firmwareVersion: String

    /// The hardware version string. Format: `x[.y[.z]]`. Maximum 64 characters.
    public var hardwareVersion: String?

    /// The services provided by the accessory.
    public var services: [Service]?

    // MARK: Callbacks

    /// Invoked to run the identify routine (max 5 seconds).
    ///
    /// The accessory must implement an identify routine so the user can locate it.
    public var identify: ((AccessoryServer, AccessoryIdentifyRequest) throws -> Void)?
}
