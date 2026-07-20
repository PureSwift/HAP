/// Pairing type flags.
///
/// Transmitted in the `kTLVType_Flags` TLV item (32-bit unsigned integer).
///
/// - SeeAlso: HAP Specification R2, Table 5-7 Pairing Type Flags
public struct PairingFlags: OptionSet, Equatable, Hashable, Sendable {

    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Transient Pair Setup (`kPairingFlag_Transient`).
    ///
    /// Pair Setup M1 – M4 without exchanging public keys.
    public static let transient = PairingFlags(rawValue: 1 << 4)

    /// Split Pair Setup (`kPairingFlag_Split`).
    ///
    /// When set with ``transient``, save the SRP verifier used in this session; when set
    /// alone, use the saved SRP verifier from the previous session.
    public static let split = PairingFlags(rawValue: 1 << 24)
}
