/// The control field of a HAP-BLE PDU header.
///
/// Defines how the PDU and the rest of the bytes in the PDU are interpreted:
/// - Bit 7: fragmentation status (0 = first fragment or unfragmented, 1 = continuation).
/// - Bits 5–6: reserved (0).
/// - Bit 4: instance ID size (0 = 16-bit, 1 = 64-bit).
/// - Bits 1–3: PDU type (0b000 = request, 0b001 = response).
/// - Bit 0: length extension, reserved (0).
///
/// - SeeAlso: HAP Specification R2, Section 7.3.3.1 HAP PDU Header - Control Field
public struct BLEPDUControlField: RawRepresentable, Equatable, Hashable, Sendable {

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// The PDU type encoded in bits 1–3.
    public enum PDUType: UInt8, Equatable, Hashable, Sendable, CaseIterable {
        case request = 0b000
        case response = 0b001
    }

    /// Whether the PDU is a continuation of a fragmented PDU.
    public var isContinuation: Bool {
        rawValue & 0b1000_0000 != 0
    }

    /// The PDU type, or `nil` for reserved values.
    public var pduType: PDUType? {
        PDUType(rawValue: (rawValue >> 1) & 0b111)
    }

    /// Whether the PDU uses 64-bit instance IDs.
    public var usesExtendedInstanceIDs: Bool {
        rawValue & 0b0001_0000 != 0
    }

    /// Whether the reserved bits (5, 6, and 0) are all zero, as required by this
    /// version of HAP-BLE.
    public var isValid: Bool {
        rawValue & 0b0110_0001 == 0
    }

    /// An unfragmented request (`0b0000 0000`).
    public static let request = BLEPDUControlField(rawValue: 0b0000_0000)

    /// An unfragmented response (`0b0000 0010`).
    public static let response = BLEPDUControlField(rawValue: 0b0000_0010)

    /// A continuation fragment of the given PDU type.
    public static func continuation(of type: PDUType) -> BLEPDUControlField {
        BLEPDUControlField(rawValue: 0b1000_0000 | type.rawValue << 1)
    }
}
