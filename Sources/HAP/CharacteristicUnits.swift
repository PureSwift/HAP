/// Units that numeric HomeKit characteristics can have.
///
/// For Apple-defined characteristics, the corresponding units are defined by the specification.
///
/// - Note: Raw values match the C `HAPCharacteristicUnits` enum (`uint8_t`).
public enum CharacteristicUnits: UInt8 {
    /// Unitless. Used for example on enumerations.
    case none = 0

    /// Degrees Celsius.
    case celsius = 1

    /// Degrees of arc.
    case arcDegrees = 2

    /// Percentage (%).
    case percentage = 3

    /// Lux (illuminance).
    case lux = 4

    /// Seconds.
    case seconds = 5
}
