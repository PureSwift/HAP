/// A HomeKit setup code, formatted as `XXX-XX-XXX` where each `X` is a `0-9` digit.
///
/// The formatted representation (including dashes) is the SRP password used during Pair Setup.
///
/// - SeeAlso: HAP Specification R2, Section 4.2.1 Setup Code
public struct SetupCode: RawRepresentable, Equatable, Hashable, Sendable {

    /// The formatted setup code, e.g. `"101-48-005"`.
    public let rawValue: String

    /// Creates a setup code from its formatted representation (`XXX-XX-XXX`).
    ///
    /// Fails if the string is not in the expected format. Use ``isSecure`` to check
    /// whether the code is acceptable for actual use.
    public init?(rawValue: String) {
        guard Self.isValidFormat(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public extension SetupCode {

    /// Creates a setup code from 8 digits without dashes, e.g. `"10148005"`.
    init?(digits: String) {
        let characters = Array(digits)
        guard characters.count == 8 else { return nil }
        var formatted = ""
        for (index, character) in characters.enumerated() {
            if index == 3 || index == 5 {
                formatted.append("-")
            }
            formatted.append(character)
        }
        self.init(rawValue: formatted)
    }

    /// Creates a setup code from its numeric value (`0...99999999`), zero-padded to 8 digits.
    init?(value: UInt32) {
        guard value <= 99_999_999 else { return nil }
        var digits = String(value)
        while digits.count < 8 {
            digits = "0" + digits
        }
        self.init(digits: digits)
    }

    /// The 8 digits of the setup code without dashes, e.g. `"10148005"`.
    var digits: String {
        rawValue.filter { $0 != "-" }
    }

    /// The numeric value of the setup code (used in the setup payload).
    var value: UInt32 {
        UInt32(digits) ?? 0
    }

    /// Whether the code is acceptable for actual use.
    ///
    /// Trivial codes (all same digit, `12345678`, `87654321`) must not be used.
    ///
    /// - SeeAlso: HAP Specification R2, Section 4.2.1.2 Invalid Setup Codes
    var isSecure: Bool {
        !Self.invalidCodes.contains(digits)
    }

    /// Generates a random, secure setup code from a cryptographically secure random number source.
    ///
    /// - SeeAlso: HAP Specification R2, Section 4.2.1.1 Generation of Setup Code
    static func random<Source: RandomNumberSource>(using source: inout Source) -> SetupCode {
        var bytes = [UInt8](repeating: 0, count: 4)
        while true {
            source.fill(&bytes)
            let value = UInt32(bytes[0]) << 24
                      | UInt32(bytes[1]) << 16
                      | UInt32(bytes[2]) << 8
                      | UInt32(bytes[3])
            guard let code = SetupCode(value: value & 0x07FF_FFFF), code.isSecure else {
                continue
            }
            return code
        }
    }
}

internal extension SetupCode {

    /// Setup codes that must not be used due to their trivial, insecure nature.
    static let invalidCodes: Set<String> = [
        "00000000", "11111111", "22222222", "33333333", "44444444",
        "55555555", "66666666", "77777777", "88888888", "99999999",
        "12345678", "87654321"
    ]

    /// Validates the `XXX-XX-XXX` format.
    static func isValidFormat(_ rawValue: String) -> Bool {
        let characters = Array(rawValue)
        guard characters.count == 10 else { return false }
        for (index, character) in characters.enumerated() {
            if index == 3 || index == 6 {
                guard character == "-" else { return false }
            } else {
                guard let ascii = character.asciiValue, ascii >= 0x30, ascii <= 0x39 else {
                    return false
                }
            }
        }
        return true
    }
}

// MARK: - CustomStringConvertible

extension SetupCode: CustomStringConvertible {

    public var description: String {
        rawValue
    }
}
