/// Pairing error codes.
///
/// Transmitted in the `kTLVType_Error` TLV item. Must only be present if the error code is not 0.
///
/// - SeeAlso: HAP Specification R2, Table 5-5 Error Codes
public enum PairingError: UInt8, Error, Equatable, Hashable, Sendable, CaseIterable {

    /// Generic error to handle unexpected errors.
    case unknown = 0x01

    /// Setup code or signature verification failed.
    case authentication = 0x02

    /// Client must look at the retry delay TLV item and wait that many seconds before retrying.
    case backoff = 0x03

    /// Server cannot accept any more pairings.
    case maxPeers = 0x04

    /// Server reached its maximum number of authentication attempts.
    case maxTries = 0x05

    /// Server pairing method is unavailable.
    case unavailable = 0x06

    /// Server is busy and cannot accept a pairing request at this time.
    case busy = 0x07
}
