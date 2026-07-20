
/// A HomeKit UUID identifying a service or characteristic type.
///
/// Apple-defined types are expressed as short-form values relative to the HAP base UUID
/// `00000000-0000-1000-8000-0026BB765291`. For example, the Light Bulb service type
/// `00000043-0000-1000-8000-0026BB765291` has the short form `43`.
///
/// - SeeAlso: HAP Specification R2, Section 6.6.1 Service and Characteristic Types
public struct HAPUUID: RawRepresentable, Equatable, Hashable, Sendable {

    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

public extension HAPUUID {

    /// Creates an Apple-defined type from its short-form value.
    ///
    /// The value occupies the first four bytes of the UUID, followed by the HAP base UUID
    /// suffix `-0000-1000-8000-0026BB765291`.
    init(appleDefined value: UInt32) {
        self.init(rawValue: UUID(uuid: (
            UInt8(truncatingIfNeeded: value >> 24),
            UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 8),
            UInt8(truncatingIfNeeded: value),
            0x00, 0x00,
            0x10, 0x00,
            0x80, 0x00,
            0x00, 0x26, 0xBB, 0x76, 0x52, 0x91
        )))
    }

    /// The short-form value if this is an Apple-defined type, `nil` otherwise.
    var appleDefinedValue: UInt32? {
        let bytes = rawValue.uuid
        guard bytes.4 == 0x00, bytes.5 == 0x00,
              bytes.6 == 0x10, bytes.7 == 0x00,
              bytes.8 == 0x80, bytes.9 == 0x00,
              bytes.10 == 0x00, bytes.11 == 0x26,
              bytes.12 == 0xBB, bytes.13 == 0x76,
              bytes.14 == 0x52, bytes.15 == 0x91
        else { return nil }
        return UInt32(bytes.0) << 24
             | UInt32(bytes.1) << 16
             | UInt32(bytes.2) << 8
             | UInt32(bytes.3)
    }

    /// Whether this type is Apple-defined (relative to the HAP base UUID).
    var isAppleDefined: Bool {
        appleDefinedValue != nil
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension HAPUUID: ExpressibleByIntegerLiteral {

    /// Creates an Apple-defined type from its short-form value, e.g. `0x43` for Light Bulb.
    public init(integerLiteral value: UInt32) {
        self.init(appleDefined: value)
    }
}

// MARK: - CustomStringConvertible

extension HAPUUID: CustomStringConvertible {

    /// The short form (uppercase hexadecimal, no leading zeros) for Apple-defined types,
    /// the full UUID string otherwise.
    ///
    /// This is the representation used in the IP attribute database JSON.
    ///
    /// - SeeAlso: HAP Specification R2, Section 6.6.1 Service and Characteristic Types
    public var description: String {
        if let value = appleDefinedValue {
            return String(value, radix: 16, uppercase: true)
        } else {
            return rawValue.uuidString
        }
    }
}
