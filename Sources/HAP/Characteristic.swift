/// A HomeKit characteristic.
///
/// Each case wraps the characteristic structure for one value format.
/// The case must always match the ``CharacteristicFormat`` of the characteristic.
public enum Characteristic {

    /// Opaque data blob.
    case data(DataCharacteristic)

    /// Boolean.
    case bool(BoolCharacteristic)

    /// Unsigned 8-bit integer.
    case uint8(UInt8Characteristic)

    /// Unsigned 16-bit integer.
    case uint16(UInt16Characteristic)

    /// Unsigned 32-bit integer.
    case uint32(UInt32Characteristic)

    /// Unsigned 64-bit integer.
    case uint64(UInt64Characteristic)

    /// Signed 32-bit integer.
    case int(IntCharacteristic)

    /// 32-bit floating point.
    case float(FloatCharacteristic)

    /// UTF-8 string.
    case string(StringCharacteristic)

    /// One or more TLV8s.
    case tlv8(TLV8Characteristic)
}

public extension Characteristic {

    /// The format of the characteristic.
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

    /// Instance ID.
    var iid: UInt64 {
        switch self {
        case let .data(characteristic): characteristic.iid
        case let .bool(characteristic): characteristic.iid
        case let .uint8(characteristic): characteristic.iid
        case let .uint16(characteristic): characteristic.iid
        case let .uint32(characteristic): characteristic.iid
        case let .uint64(characteristic): characteristic.iid
        case let .int(characteristic): characteristic.iid
        case let .float(characteristic): characteristic.iid
        case let .string(characteristic): characteristic.iid
        case let .tlv8(characteristic): characteristic.iid
        }
    }

    /// The type of the characteristic.
    var characteristicType: HAPUUID {
        switch self {
        case let .data(characteristic): characteristic.characteristicType
        case let .bool(characteristic): characteristic.characteristicType
        case let .uint8(characteristic): characteristic.characteristicType
        case let .uint16(characteristic): characteristic.characteristicType
        case let .uint32(characteristic): characteristic.characteristicType
        case let .uint64(characteristic): characteristic.characteristicType
        case let .int(characteristic): characteristic.characteristicType
        case let .float(characteristic): characteristic.characteristicType
        case let .string(characteristic): characteristic.characteristicType
        case let .tlv8(characteristic): characteristic.characteristicType
        }
    }

    /// Characteristic properties.
    var properties: CharacteristicProperties {
        switch self {
        case let .data(characteristic): characteristic.properties
        case let .bool(characteristic): characteristic.properties
        case let .uint8(characteristic): characteristic.properties
        case let .uint16(characteristic): characteristic.properties
        case let .uint32(characteristic): characteristic.properties
        case let .uint64(characteristic): characteristic.properties
        case let .int(characteristic): characteristic.properties
        case let .float(characteristic): characteristic.properties
        case let .string(characteristic): characteristic.properties
        case let .tlv8(characteristic): characteristic.properties
        }
    }
}
