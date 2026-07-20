/// A HomeKit setup payload, encoded as a URI of the form `X-HM://XXXXXXXXXYYYY`.
///
/// The first 9 characters after the scheme encode a 46-bit value as a base-36 string
/// containing the version, accessory category, transport flags, and setup code. The last
/// 4 characters are the setup ID. The payload is delivered to controllers via QR code or NFC.
///
/// - SeeAlso: HAP Specification R13, Section 4.3 Format of Setup Payload
public struct SetupPayload: Equatable, Hashable, Sendable {

    /// The category of the accessory (lower 8 bits are encoded in the payload).
    public var category: AccessoryCategory

    /// Accessory supports Wi-Fi Accessory Configuration (WAC) for configuring wireless credentials.
    public var supportsWAC: Bool

    /// Accessory supports HAP over BLE transport.
    public var supportsBLE: Bool

    /// Accessory supports HAP over IP transport. Must be set if ``supportsWAC`` is set.
    public var supportsIP: Bool

    /// Accessory is paired with a controller.
    ///
    /// Only used by accessories with programmable NFC tags, which must not expose the
    /// setup code once paired.
    public var isPaired: Bool

    /// The setup code.
    public var setupCode: SetupCode

    /// The setup ID.
    public var setupID: SetupID

    public init(
        category: AccessoryCategory,
        supportsWAC: Bool = false,
        supportsBLE: Bool = false,
        supportsIP: Bool = false,
        isPaired: Bool = false,
        setupCode: SetupCode,
        setupID: SetupID
    ) {
        self.category = category
        self.supportsWAC = supportsWAC
        self.supportsBLE = supportsBLE
        self.supportsIP = supportsIP
        self.isPaired = isPaired
        self.setupCode = setupCode
        self.setupID = setupID
    }
}

public extension SetupPayload {

    /// The encoded setup payload URI, e.g. `"X-HM://007JNU5AE7OSX"`.
    var uri: String {
        var value: UInt64 = 0
        value |= UInt64(category.rawValue) << 31
        if supportsWAC { value |= 1 << 30 }
        if supportsBLE { value |= 1 << 29 }
        if supportsIP { value |= 1 << 28 }
        if isPaired { value |= 1 << 27 }
        value |= UInt64(setupCode.value)
        return "X-HM://" + Self.base36Encode(value, width: 9) + setupID.rawValue
    }

    /// Decodes a setup payload URI.
    init?(uri: String) {
        let characters = Array(uri)
        guard characters.count == 7 + 9 + 4,
              String(characters[0 ..< 7]) == "X-HM://",
              let value = Self.base36Decode(String(characters[7 ..< 16])),
              let setupID = SetupID(rawValue: String(characters[16 ..< 20]))
        else { return nil }
        // Bits 45-43 (version) and 42-39 (reserved) must be zero.
        guard value >> 39 == 0 else { return nil }
        let codeValue = UInt32(truncatingIfNeeded: value) & 0x07FF_FFFF
        guard let category = AccessoryCategory(rawValue: UInt8(truncatingIfNeeded: value >> 31)),
              let setupCode = SetupCode(value: codeValue)
        else { return nil }
        self.init(
            category: category,
            supportsWAC: value & (1 << 30) != 0,
            supportsBLE: value & (1 << 29) != 0,
            supportsIP: value & (1 << 28) != 0,
            isPaired: value & (1 << 27) != 0,
            setupCode: setupCode,
            setupID: setupID
        )
    }
}

internal extension SetupPayload {

    /// Encodes a value as a fixed-width base-36 string using digits `0-9`, `A-Z`.
    static func base36Encode(_ value: UInt64, width: Int) -> String {
        var digits = [Character](repeating: "0", count: width)
        var value = value
        var index = width - 1
        while value > 0, index >= 0 {
            let digit = UInt8(truncatingIfNeeded: value % 36)
            digits[index] = Character(UnicodeScalar(digit < 10 ? 0x30 + digit : 0x41 + digit - 10))
            value /= 36
            index -= 1
        }
        return String(digits)
    }

    /// Decodes a base-36 string using digits `0-9`, `A-Z`.
    static func base36Decode(_ string: String) -> UInt64? {
        var result: UInt64 = 0
        for character in string {
            guard let ascii = character.asciiValue else { return nil }
            let digit: UInt64
            switch ascii {
            case 0x30 ... 0x39: digit = UInt64(ascii - 0x30)
            case 0x41 ... 0x5A: digit = UInt64(ascii - 0x41) + 10
            default: return nil
            }
            result = result * 36 + digit
        }
        return result
    }
}

// MARK: - CustomStringConvertible

extension SetupPayload: CustomStringConvertible {

    public var description: String {
        uri
    }
}
