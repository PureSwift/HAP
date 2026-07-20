import TLVCoding

/// HAP-BLE signature read response bodies.
///
/// Controllers perform a secured signature read after pair-verify and validate the service
/// and characteristic types, instance IDs, and metadata against the unsecured GATT database.
///
/// - SeeAlso: HAP Specification R2, Sections 7.3.4.2 and 7.3.4.13
public extension Characteristic {

    /// The `HAP-Characteristic-Properties-Descriptor` wire bitmask.
    ///
    /// - SeeAlso: HAP Specification R2, Section 7.4.4.6.1 HAP Characteristic Properties
    var blePropertiesDescriptor: UInt16 {
        var mask: UInt16 = 0
        if properties.contains(.bleReadableWithoutSecurity) { mask |= 0x0001 }
        if properties.contains(.bleWritableWithoutSecurity) { mask |= 0x0002 }
        if properties.contains(.supportsAuthorizationData) { mask |= 0x0004 }
        if properties.contains(.requiresTimedWrite) { mask |= 0x0008 }
        if properties.contains(.readable) { mask |= 0x0010 }
        if properties.contains(.writable) { mask |= 0x0020 }
        if properties.contains(.hidden) { mask |= 0x0040 }
        if properties.contains(.supportsEventNotification) { mask |= 0x0080 }
        if properties.contains(.bleSupportsDisconnectedNotification) { mask |= 0x0100 }
        if properties.contains(.bleSupportsBroadcastNotification) { mask |= 0x0200 }
        return mask
    }

    /// The body of a `HAP-Characteristic-Signature-Read-Response`.
    ///
    /// Contains the characteristic type, the owning service's instance ID and type, and all
    /// metadata associated with the characteristic (properties, optional user description,
    /// presentation format, valid range, step value, and valid values).
    ///
    /// - SeeAlso: HAP Specification R2, Section 7.3.4.2
    func bleSignatureReadResponseBody(service: Service) -> Data {
        var container = TLVContainer()
        container.append(.characteristicType, characteristicType.bleData)
        container.append(.serviceInstanceID, Data.littleEndian(UInt16(truncatingIfNeeded: service.iid)))
        container.append(.serviceType, service.serviceType.bleData)
        container.append(.characteristicProperties, Data.littleEndian(blePropertiesDescriptor))
        if let manufacturerDescription {
            container.append(.userDescription, Data(Array(manufacturerDescription.utf8)))
        }
        container.append(
            .presentationFormat,
            BLEPresentationFormat(format: format, unit: units ?? CharacteristicUnits.none).data
        )
        if let validRange = bleValidRange {
            container.append(.validRange, validRange)
        }
        if let stepValue = bleStepValue {
            container.append(.stepValue, stepValue)
        }
        if let validValues = bleValidValues {
            container.append(.validValues, validValues)
        }
        if let validValuesRanges = bleValidValuesRanges {
            container.append(.validValuesRange, validValuesRanges)
        }
        return Data(container.data)
    }

    /// Description of the characteristic provided by the accessory manufacturer.
    var manufacturerDescription: String? {
        switch self {
        case let .data(characteristic): characteristic.manufacturerDescription
        case let .bool(characteristic): characteristic.manufacturerDescription
        case let .uint8(characteristic): characteristic.manufacturerDescription
        case let .uint16(characteristic): characteristic.manufacturerDescription
        case let .uint32(characteristic): characteristic.manufacturerDescription
        case let .uint64(characteristic): characteristic.manufacturerDescription
        case let .int(characteristic): characteristic.manufacturerDescription
        case let .float(characteristic): characteristic.manufacturerDescription
        case let .string(characteristic): characteristic.manufacturerDescription
        case let .tlv8(characteristic): characteristic.manufacturerDescription
        }
    }

    /// The unit of the characteristic value, for formats that carry one.
    var units: CharacteristicUnits? {
        switch self {
        case let .uint8(characteristic): characteristic.units
        case let .uint16(characteristic): characteristic.units
        case let .uint32(characteristic): characteristic.units
        case let .uint64(characteristic): characteristic.units
        case let .int(characteristic): characteristic.units
        case let .float(characteristic): characteristic.units
        case .data, .bool, .string, .tlv8: nil
        }
    }
}

public extension Service {

    /// The `HAP-Service-Properties` wire bitmask.
    var blePropertiesDescriptor: UInt16 {
        var mask: UInt16 = 0
        if properties.contains(.primaryService) { mask |= 0x0001 }
        if properties.contains(.hidden) { mask |= 0x0002 }
        if properties.contains(.bleSupportsConfiguration) { mask |= 0x0004 }
        return mask
    }

    /// The body of a `HAP-Service-Signature-Read-Response`.
    ///
    /// - SeeAlso: HAP Specification R2, Section 7.3.4.13
    var bleSignatureReadResponseBody: Data {
        var container = TLVContainer()
        container.append(.serviceProperties, Data.littleEndian(blePropertiesDescriptor))
        var linkedServiceBytes = [UInt8]()
        for linkedService in linkedServices ?? [] {
            linkedServiceBytes.append(UInt8(truncatingIfNeeded: linkedService))
            linkedServiceBytes.append(UInt8(truncatingIfNeeded: linkedService >> 8))
        }
        container.append(.linkedServices, Data(linkedServiceBytes))
        return Data(container.data)
    }

    /// The response body for a signature read with an invalid service instance ID:
    /// properties set to 0 and no linked services.
    ///
    /// - SeeAlso: HAP Specification R2, Section 7.3.4.13
    static var bleEmptySignatureReadResponseBody: Data {
        var container = TLVContainer()
        container.append(.serviceProperties, Data.littleEndian(0 as UInt16))
        container.append(.linkedServices, Data())
        return Data(container.data)
    }
}

// MARK: - Metadata Serialization

private extension Characteristic {

    /// The `GATT-Valid-Range` value (minimum ‖ maximum, little-endian), omitted when the
    /// range covers the full value range of the format.
    var bleValidRange: Data? {
        switch self {
        case .data, .bool, .string, .tlv8:
            return nil
        case let .uint8(characteristic):
            guard characteristic.minimumValue != 0 || characteristic.maximumValue != .max
            else { return nil }
            return Data([characteristic.minimumValue, characteristic.maximumValue])
        case let .uint16(characteristic):
            guard characteristic.minimumValue != 0 || characteristic.maximumValue != .max
            else { return nil }
            return Data(
                littleEndianBytes(characteristic.minimumValue)
                    + littleEndianBytes(characteristic.maximumValue)
            )
        case let .uint32(characteristic):
            guard characteristic.minimumValue != 0 || characteristic.maximumValue != .max
            else { return nil }
            return Data(
                littleEndianBytes(characteristic.minimumValue)
                    + littleEndianBytes(characteristic.maximumValue)
            )
        case let .uint64(characteristic):
            guard characteristic.minimumValue != 0 || characteristic.maximumValue != .max
            else { return nil }
            return Data(
                littleEndianBytes(characteristic.minimumValue)
                    + littleEndianBytes(characteristic.maximumValue)
            )
        case let .int(characteristic):
            guard characteristic.minimumValue != .min || characteristic.maximumValue != .max
            else { return nil }
            return Data(
                littleEndianBytes(UInt32(bitPattern: characteristic.minimumValue))
                    + littleEndianBytes(UInt32(bitPattern: characteristic.maximumValue))
            )
        case let .float(characteristic):
            guard characteristic.minimumValue != -.infinity
                    || characteristic.maximumValue != .infinity
            else { return nil }
            return Data(
                littleEndianBytes(characteristic.minimumValue.bitPattern)
                    + littleEndianBytes(characteristic.maximumValue.bitPattern)
            )
        }
    }

    /// The `HAP-Step-Value-Descriptor` value (little-endian), omitted when the step does
    /// not restrict the value (integer steps of 0 or 1, float steps of 0).
    var bleStepValue: Data? {
        switch self {
        case .data, .bool, .string, .tlv8:
            return nil
        case let .uint8(characteristic):
            guard characteristic.stepValue > 1 else { return nil }
            return Data([characteristic.stepValue])
        case let .uint16(characteristic):
            guard characteristic.stepValue > 1 else { return nil }
            return Data.littleEndian(characteristic.stepValue)
        case let .uint32(characteristic):
            guard characteristic.stepValue > 1 else { return nil }
            return Data.littleEndian(characteristic.stepValue)
        case let .uint64(characteristic):
            guard characteristic.stepValue > 1 else { return nil }
            return Data.littleEndian(characteristic.stepValue)
        case let .int(characteristic):
            guard characteristic.stepValue > 1 else { return nil }
            return Data.littleEndian(UInt32(bitPattern: characteristic.stepValue))
        case let .float(characteristic):
            guard characteristic.stepValue > 0 else { return nil }
            return Data.littleEndian(characteristic.stepValue.bitPattern)
        }
    }

    /// The `HAP-Valid-Values-Descriptor` value (UInt8 characteristics only).
    var bleValidValues: Data? {
        guard case let .uint8(characteristic) = self,
              let validValues = characteristic.validValues
        else { return nil }
        return Data(validValues)
    }

    /// The `HAP-Valid-Values-Range-Descriptor` value (UInt8 characteristics only).
    var bleValidValuesRanges: Data? {
        guard case let .uint8(characteristic) = self,
              let ranges = characteristic.validValuesRanges
        else { return nil }
        var bytes = [UInt8]()
        for range in ranges {
            bytes.append(range.lowerBound)
            bytes.append(range.upperBound)
        }
        return Data(bytes)
    }
}

// MARK: - Helpers

internal extension HAPUUID {

    /// The 16-byte little-endian serialization used in HAP-BLE PDUs.
    var bleData: Data {
        let bytes = rawValue.uuid
        return Data([
            bytes.15, bytes.14, bytes.13, bytes.12,
            bytes.11, bytes.10, bytes.9, bytes.8,
            bytes.7, bytes.6, bytes.5, bytes.4,
            bytes.3, bytes.2, bytes.1, bytes.0
        ])
    }
}

internal func littleEndianBytes(_ value: UInt16) -> [UInt8] {
    [
        UInt8(truncatingIfNeeded: value),
        UInt8(truncatingIfNeeded: value >> 8)
    ]
}

internal func littleEndianBytes(_ value: UInt32) -> [UInt8] {
    [
        UInt8(truncatingIfNeeded: value),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 24)
    ]
}

internal func littleEndianBytes(_ value: UInt64) -> [UInt8] {
    [
        UInt8(truncatingIfNeeded: value),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 32),
        UInt8(truncatingIfNeeded: value >> 40),
        UInt8(truncatingIfNeeded: value >> 48),
        UInt8(truncatingIfNeeded: value >> 56)
    ]
}

internal extension Data {

    static func littleEndian(_ value: UInt16) -> Data {
        Data(littleEndianBytes(value))
    }

    static func littleEndian(_ value: UInt32) -> Data {
        Data(littleEndianBytes(value))
    }

    static func littleEndian(_ value: UInt64) -> Data {
        Data(littleEndianBytes(value))
    }
}

private extension TLVContainer {

    mutating func append(_ type: BLEPDUParamType, _ value: Data) {
        items.append(TLVItem(type: type.typeCode, value: .init(value)))
    }
}
