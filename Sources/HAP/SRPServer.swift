
/// The server side of an SRP-6a session (3072-bit group, SHA-512).
///
/// Used during Pair Setup: the accessory sends its public key `B` and salt in M2, processes
/// the controller's public key `A` and proof `M1` from M3, and responds with its own proof
/// `M2` in M4. The session key `K` encrypts the subsequent exchange messages.
///
/// - SeeAlso: HAP Specification R2, Section 5.5 Secure Remote Password, Section 5.6 Pair Setup
public protocol SRPServer {

    /// The server's SRP public key (`B`).
    var publicKey: Data { get }

    /// Processes the client's SRP public key (`A`) and computes the shared secret.
    ///
    /// - Throws: ``HAPError/invalidData`` if the client public key is illegal (e.g. `A mod N == 0`).
    mutating func processClientPublicKey(_ clientPublicKey: Data) throws(HAPError)

    /// Verifies the client's proof (`M1`) and returns the server's proof (`M2`).
    ///
    /// Must be called after ``processClientPublicKey(_:)``.
    ///
    /// - Throws: ``HAPError/notAuthorized`` if the client proof does not match
    ///   (wrong setup code).
    mutating func verifyClientProof(_ clientProof: Data) throws(HAPError) -> Data

    /// The SRP session key (`K`).
    ///
    /// Only valid after ``processClientPublicKey(_:)`` has succeeded.
    var sessionKey: Data { get }
}
