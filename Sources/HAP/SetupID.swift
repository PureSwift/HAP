/// A HomeKit setup ID: an alphanumeric string of 4 (`0-9`, `A-Z`) characters.
///
/// The setup ID is persistent across reboots and factory reset of the accessory. It must be
/// different than the device ID, serial number, model, or accessory name, and must be random
/// for each accessory instance manufactured by an accessory manufacturer.
///
/// - SeeAlso: HAP Specification R13, Section 4.2.2 Setup ID
public struct SetupID: RawRepresentable, Equatable, Hashable, Sendable {

    /// The 4-character setup ID, e.g. `"7OSX"`.
    public let rawValue: String

    public init?(rawValue: String) {
        let characters = Array(rawValue)
        guard characters.count == 4 else { return nil }
        for character in characters {
            guard let ascii = character.asciiValue,
                  (ascii >= 0x30 && ascii <= 0x39) || (ascii >= 0x41 && ascii <= 0x5A)
            else { return nil }
        }
        self.rawValue = rawValue
    }
}

// MARK: - CustomStringConvertible

extension SetupID: CustomStringConvertible {

    public var description: String {
        rawValue
    }
}
