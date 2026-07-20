/// The GATT Characteristic Presentation Format descriptor of a HAP characteristic.
///
/// Serialized as 7 bytes: `format (1) ‖ exponent (1, 0) ‖ unit (2, little-endian) ‖
/// namespace (1, Bluetooth SIG) ‖ description (2, 0)`.
///
/// - SeeAlso: HAP Specification R2, Section 7.4.4.6.3 Characteristic Presentation Format
public struct BLEPresentationFormat: Equatable, Hashable, Sendable {

    /// The Bluetooth SIG format code.
    public var format: UInt8

    /// The Bluetooth SIG unit code.
    public var unit: UInt16

    public init(format: UInt8, unit: UInt16) {
        self.format = format
        self.unit = unit
    }

    /// Creates the presentation format for a HAP characteristic format and unit.
    public init(format: CharacteristicFormat, unit: CharacteristicUnits) {
        self.init(
            format: Self.bluetoothFormat(for: format),
            unit: Self.bluetoothUnit(for: unit)
        )
    }

    /// The serialized descriptor (7 bytes).
    public var data: Data {
        Data([
            format,
            0x00,                                  // exponent
            UInt8(truncatingIfNeeded: unit),
            UInt8(truncatingIfNeeded: unit >> 8),
            0x01,                                  // namespace: Bluetooth SIG
            0x00, 0x00                             // description
        ])
    }

    /// The Bluetooth SIG format code for a HAP characteristic format.
    public static func bluetoothFormat(for format: CharacteristicFormat) -> UInt8 {
        switch format {
        case .bool: 0x01
        case .uint8: 0x04
        case .uint16: 0x06
        case .uint32: 0x08
        case .uint64: 0x0A
        case .int: 0x10
        case .float: 0x14
        case .string: 0x19
        case .data, .tlv8: 0x1B
        }
    }

    /// The Bluetooth SIG unit code for a HAP characteristic unit.
    public static func bluetoothUnit(for unit: CharacteristicUnits) -> UInt16 {
        switch unit {
        case .none: 0x2700
        case .celsius: 0x272F
        case .arcDegrees: 0x2763
        case .percentage: 0x27AD
        case .lux: 0x2731
        case .seconds: 0x2703
        }
    }
}
