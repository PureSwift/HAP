/// Permissions of a paired controller.
///
/// Transmitted in the `kTLVType_Permissions` TLV item.
///
/// - SeeAlso: HAP Specification R2, Table 5-6 TLV Values
public struct PairingPermissions: OptionSet, Equatable, Hashable, Sendable {

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Admin that is able to add and remove pairings against the accessory.
    ///
    /// A controller without this permission is a regular user.
    public static let admin = PairingPermissions(rawValue: 1 << 0)
}
