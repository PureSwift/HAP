/// Method to use for pairing.
///
/// Transmitted in the `kTLVType_Method` TLV item.
///
/// - SeeAlso: HAP Specification R2, Table 5-3 Methods
public enum PairingMethod: UInt8, Equatable, Hashable, Sendable, CaseIterable {

    /// Pair Setup.
    case pairSetup = 0

    /// Pair Setup with Auth.
    case pairSetupWithAuth = 1

    /// Pair Verify.
    case pairVerify = 2

    /// Add Pairing.
    case addPairing = 3

    /// Remove Pairing.
    case removePairing = 4

    /// List Pairings.
    case listPairings = 5
}
