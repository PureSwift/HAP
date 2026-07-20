/// The value of a HomeKit characteristic.
///
/// The case must always match the ``CharacteristicFormat`` of the characteristic.
public enum CharacteristicValue: Equatable, Hashable, Sendable {

    /// Opaque data blob.
    case data(Data)

    /// Boolean.
    case bool(Bool)

    /// Unsigned 8-bit integer.
    case uint8(UInt8)

    /// Unsigned 16-bit integer.
    case uint16(UInt16)

    /// Unsigned 32-bit integer.
    case uint32(UInt32)

    /// Unsigned 64-bit integer.
    case uint64(UInt64)

    /// Signed 32-bit integer.
    case int(Int32)

    /// 32-bit floating point.
    case float(Float)

    /// UTF-8 string.
    case string(String)

    /// One or more TLV8s.
    case tlv8(Data)
}

public extension CharacteristicValue {

    /// The format of the value.
    var format: CharacteristicFormat {
        switch self {
        case .data: .data
        case .bool: .bool
        case .uint8: .uint8
        case .uint16: .uint16
        case .uint32: .uint32
        case .uint64: .uint64
        case .int: .int
        case .float: .float
        case .string: .string
        case .tlv8: .tlv8
        }
    }
}

// MARK: - HAP-BLE Wire Format

public extension CharacteristicValue {

    /// The HAP-BLE serialization of the value.
    ///
    /// Integers and floats are little-endian; booleans are a single byte; strings are
    /// UTF-8 without a terminator; data and TLV8 values are raw bytes.
    ///
    /// - SeeAlso: HAP Specification R2, Section 7.4.5.1 Characteristic Format Types
    var bleData: Data {
        switch self {
        case let .data(value): value
        case let .bool(value): Data([value ? 1 : 0])
        case let .uint8(value): Data([value])
        case let .uint16(value): Data(littleEndianBytes(value))
        case let .uint32(value): Data(littleEndianBytes(value))
        case let .uint64(value): Data(littleEndianBytes(value))
        case let .int(value): Data(littleEndianBytes(UInt32(bitPattern: value)))
        case let .float(value): Data(littleEndianBytes(value.bitPattern))
        case let .string(value): Data(Array(value.utf8))
        case let .tlv8(value): value
        }
    }

    /// Decodes a HAP-BLE serialized value of the given format.
    ///
    /// Fails on length mismatches and boolean values other than 0 or 1.
    init?(bleData: Data, format: CharacteristicFormat) {
        let bytes = Array(bleData)
        switch format {
        case .data:
            self = .data(bleData)
        case .bool:
            guard bytes.count == 1, bytes[0] <= 1 else { return nil }
            self = .bool(bytes[0] == 1)
        case .uint8:
            guard bytes.count == 1 else { return nil }
            self = .uint8(bytes[0])
        case .uint16:
            guard bytes.count == 2 else { return nil }
            self = .uint16(UInt16(littleEndianBytes: bytes))
        case .uint32:
            guard bytes.count == 4 else { return nil }
            self = .uint32(UInt32(littleEndianBytes: bytes))
        case .uint64:
            guard bytes.count == 8 else { return nil }
            self = .uint64(UInt64(littleEndianBytes: bytes))
        case .int:
            guard bytes.count == 4 else { return nil }
            self = .int(Int32(bitPattern: UInt32(littleEndianBytes: bytes)))
        case .float:
            guard bytes.count == 4 else { return nil }
            self = .float(Float(bitPattern: UInt32(littleEndianBytes: bytes)))
        case .string:
            self = .string(String(decoding: bytes, as: UTF8.self))
        case .tlv8:
            self = .tlv8(bleData)
        }
    }
}

// MARK: - Validation

public extension Characteristic {

    /// Whether a value is valid for this characteristic.
    ///
    /// Checks that the value's format matches the characteristic and that it satisfies the
    /// characteristic's constraints: numeric range and step, the valid values lists of UInt8
    /// characteristics, and the maximum length of string and data values.
    func isValidValue(_ value: CharacteristicValue) -> Bool {
        switch (self, value) {
        case let (.data(characteristic), .data(value)):
            return value.count <= Int(characteristic.maxLength)
        case (.bool, .bool):
            return true
        case let (.uint8(characteristic), .uint8(value)):
            if let validValues = characteristic.validValues,
               let validValuesRanges = characteristic.validValuesRanges {
                return validValues.contains(value)
                    || validValuesRanges.contains { $0.contains(value) }
            }
            if let validValues = characteristic.validValues {
                return validValues.contains(value)
            }
            if let validValuesRanges = characteristic.validValuesRanges {
                return validValuesRanges.contains { $0.contains(value) }
            }
            return Self.isValid(
                value,
                minimum: characteristic.minimumValue,
                maximum: characteristic.maximumValue,
                step: characteristic.stepValue
            )
        case let (.uint16(characteristic), .uint16(value)):
            return Self.isValid(
                value,
                minimum: characteristic.minimumValue,
                maximum: characteristic.maximumValue,
                step: characteristic.stepValue
            )
        case let (.uint32(characteristic), .uint32(value)):
            return Self.isValid(
                value,
                minimum: characteristic.minimumValue,
                maximum: characteristic.maximumValue,
                step: characteristic.stepValue
            )
        case let (.uint64(characteristic), .uint64(value)):
            return Self.isValid(
                value,
                minimum: characteristic.minimumValue,
                maximum: characteristic.maximumValue,
                step: characteristic.stepValue
            )
        case let (.int(characteristic), .int(value)):
            guard value >= characteristic.minimumValue,
                  value <= characteristic.maximumValue
            else { return false }
            guard characteristic.stepValue > 1 else { return true }
            let offset = Int64(value) - Int64(characteristic.minimumValue)
            return offset % Int64(characteristic.stepValue) == 0
        case let (.float(characteristic), .float(value)):
            return value.isFinite
                && value >= characteristic.minimumValue
                && value <= characteristic.maximumValue
        case let (.string(characteristic), .string(value)):
            return value.utf8.count <= Int(characteristic.maxLength)
        case (.tlv8, .tlv8):
            return true
        default:
            // Format mismatch.
            return false
        }
    }
}

private extension Characteristic {

    static func isValid<Value: FixedWidthInteger & UnsignedInteger>(
        _ value: Value,
        minimum: Value,
        maximum: Value,
        step: Value
    ) -> Bool {
        guard value >= minimum, value <= maximum else { return false }
        guard step > 1 else { return true }
        return (value - minimum) % step == 0
    }
}

// MARK: - Helpers

private extension UInt16 {

    init(littleEndianBytes bytes: [UInt8]) {
        self = UInt16(bytes[0]) | UInt16(bytes[1]) << 8
    }
}

private extension UInt32 {

    init(littleEndianBytes bytes: [UInt8]) {
        self = UInt32(bytes[0])
            | UInt32(bytes[1]) << 8
            | UInt32(bytes[2]) << 16
            | UInt32(bytes[3]) << 24
    }
}

private extension UInt64 {

    init(littleEndianBytes bytes: [UInt8]) {
        var value: UInt64 = 0
        for (index, byte) in bytes.enumerated() {
            value |= UInt64(byte) << (8 * index)
        }
        self = value
    }
}
