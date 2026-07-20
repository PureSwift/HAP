import TLVCoding

/// Additional parameter types used in HAP-BLE PDU body TLVs.
///
/// An accessory must parse the TLV8 entries and ignore parameters that it does not support.
///
/// - SeeAlso: HAP Specification R2, Table 7-10 Additional Parameter Types Description
public enum BLEPDUParamType: UInt8, Equatable, Hashable, Sendable, CaseIterable {

    /// HAP-Param-Value.
    case value = 0x01

    /// HAP-Param-Additional-Authorization-Data.
    case additionalAuthorizationData = 0x02

    /// HAP-Param-Origin (local vs remote).
    case origin = 0x03

    /// HAP-Param-Characteristic-Type.
    case characteristicType = 0x04

    /// HAP-Param-Characteristic-Instance-ID.
    case characteristicInstanceID = 0x05

    /// HAP-Param-Service-Type.
    case serviceType = 0x06

    /// HAP-Param-Service-Instance-ID.
    case serviceInstanceID = 0x07

    /// HAP-Param-TTL.
    case ttl = 0x08

    /// HAP-Param-Return-Response.
    case returnResponse = 0x09

    /// HAP-Param-HAP-Characteristic-Properties-Descriptor.
    case characteristicProperties = 0x0A

    /// HAP-Param-GATT-User-Description-Descriptor.
    case userDescription = 0x0B

    /// HAP-Param-GATT-Presentation-Format-Descriptor.
    case presentationFormat = 0x0C

    /// HAP-Param-GATT-Valid-Range.
    case validRange = 0x0D

    /// HAP-Param-HAP-Step-Value-Descriptor.
    case stepValue = 0x0E

    /// HAP-Param-HAP-Service-Properties.
    case serviceProperties = 0x0F

    /// HAP-Param-HAP-Linked-Services.
    case linkedServices = 0x10

    /// HAP-Param-HAP-Valid-Values-Descriptor.
    case validValues = 0x11

    /// HAP-Param-HAP-Valid-Values-Range-Descriptor.
    case validValuesRange = 0x12
}

public extension BLEPDUParamType {

    /// The TLV type code for use with `TLVCoding`.
    var typeCode: TLVTypeCode {
        TLVTypeCode(rawValue: rawValue)
    }
}
