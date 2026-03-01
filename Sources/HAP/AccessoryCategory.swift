/// The category of a HomeKit accessory.
///
/// An accessory with support for multiple categories should advertise the primary category.
/// If a primary category cannot be determined or is not among the well-defined categories, use ``other``.
///
/// - SeeAlso: HAP Specification R14, Section 13 Accessory Categories
///
/// - Note: Raw values match the C `HAPAccessoryCategory` enum (`uint8_t`).
public enum AccessoryCategory: UInt8, Sendable, CaseIterable {
    
    /// Accessory that is accessed through a bridge.
    case bridgedAccessory = 0

    /// Other.
    case other = 1

    /// Bridges.
    case bridges = 2

    /// Fans.
    case fans = 3

    /// Garage Door Openers.
    ///
    /// Must use programmable tags if NFC is supported.
    case garageDoorOpeners = 4

    /// Lighting.
    case lighting = 5

    /// Locks.
    ///
    /// Must use programmable tags if NFC is supported.
    case locks = 6

    /// Outlets.
    case outlets = 7

    /// Switches.
    case switches = 8

    /// Thermostats.
    case thermostats = 9

    /// Sensors.
    case sensors = 10

    /// Security Systems.
    ///
    /// Must use programmable tags if NFC is supported.
    case securitySystems = 11

    /// Doors.
    ///
    /// Must use programmable tags if NFC is supported.
    case doors = 12

    /// Windows.
    ///
    /// Must use programmable tags if NFC is supported.
    case windows = 13

    /// Window Coverings.
    case windowCoverings = 14

    /// Programmable Switches.
    case programmableSwitches = 15

    /// Range Extenders.
    ///
    /// - Note: Obsolete since R10.
    case rangeExtenders = 16

    /// IP Cameras.
    case ipCameras = 17

    /// Air Purifiers.
    case airPurifiers = 19

    /// Heaters.
    case heaters = 20

    /// Air Conditioners.
    case airConditioners = 21

    /// Humidifiers.
    case humidifiers = 22

    /// Dehumidifiers.
    case dehumidifiers = 23

    /// Sprinklers.
    case sprinklers = 28

    /// Faucets.
    case faucets = 29

    /// Shower Systems.
    case showerSystems = 30
}