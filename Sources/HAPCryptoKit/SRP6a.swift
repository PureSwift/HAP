import BigInt
import Crypto
import Foundation
import FoundationEmbedded
import HAP

/// SRP-6a operations for HAP Pair Setup: the 3072-bit group from RFC 5054 with SHA-512.
///
/// Matches the HAP SRP modifications (§5.5) and the ADK reference implementation:
/// - `x = H(s ‖ H(I ":" P))`
/// - `k = H(N ‖ PAD(g))`
/// - `u = H(PAD(A) ‖ PAD(B))`, used as a full 64-byte integer
/// - `K = H(S)` with leading zeros of `S` stripped
/// - `M1 = H((H(N) ⊕ H(g)) ‖ H(I) ‖ s ‖ A ‖ B ‖ K)` with leading zeros of `A` and `B` stripped
/// - `M2 = H(PAD(A) ‖ M1 ‖ K)`
///
/// - SeeAlso: HAP Specification R2, Section 5.5 Secure Remote Password
public enum SRP6a {

    /// Size of the group prime `N` (and of padded group elements) in bytes.
    public static let primeByteCount = 384

    static let prime = BigUInt(Foundation.Data(SRPGroup.primeBytes))

    static let generator = BigUInt(SRPGroup.generatorBytes[0])
}

internal extension SRP6a {

    /// SHA-512 over the concatenation of byte chunks.
    static func sha512(_ chunks: [[UInt8]]) -> [UInt8] {
        var hasher = SHA512()
        for chunk in chunks {
            hasher.update(data: Foundation.Data(chunk))
        }
        return Array(hasher.finalize())
    }

    /// Serializes a group element big-endian, zero-padded to the size of `N`.
    static func padded(_ value: BigUInt) -> [UInt8] {
        let bytes = Array(value.serialize())
        precondition(bytes.count <= primeByteCount)
        return [UInt8](repeating: 0, count: primeByteCount - bytes.count) + bytes
    }

    /// Removes leading zero bytes.
    static func stripped(_ bytes: [UInt8]) -> [UInt8] {
        var index = 0
        while index < bytes.count, bytes[index] == 0 {
            index += 1
        }
        return Array(bytes[index...])
    }

    /// `x = H(s ‖ H(I ":" P))`
    static func passwordHash(username: [UInt8], password: [UInt8], salt: [UInt8]) -> BigUInt {
        let identity = sha512([username + [0x3A] + password])
        return BigUInt(Foundation.Data(sha512([salt, identity])))
    }

    /// `k = H(N ‖ PAD(g))`
    static func multiplier() -> BigUInt {
        BigUInt(Foundation.Data(sha512([SRPGroup.primeBytes, padded(generator)])))
    }

    /// `v = g^x mod N`, zero-padded to the size of `N`.
    static func verifier(username: [UInt8], password: [UInt8], salt: [UInt8]) -> [UInt8] {
        let x = passwordHash(username: username, password: password, salt: salt)
        return padded(generator.power(x, modulus: prime))
    }
}

// MARK: - Server Session

/// The server side of an SRP-6a Pair Setup session.
public struct SRP6aServer: SRPServer {

    /// The server's public key `B`, zero-padded to 384 bytes.
    public let publicKey: FoundationEmbedded.Data

    /// The session key `K`. Only valid after ``processClientPublicKey(_:)`` has succeeded.
    public private(set) var sessionKey: FoundationEmbedded.Data

    let username: [UInt8]
    let salt: [UInt8]
    let verifier: BigUInt
    let privateKey: BigUInt
    var clientPublicKey: [UInt8]?

    /// Creates a server session with an explicit private key `b`.
    ///
    /// - Note: Use ``SwiftCryptoProvider/makeSRPServer(username:salt:verifier:)`` to create
    ///   a session with a random private key.
    public init(
        username: String,
        salt: FoundationEmbedded.Data,
        verifier: FoundationEmbedded.Data,
        privateKey: FoundationEmbedded.Data
    ) {
        self.username = Array(username.utf8)
        self.salt = Array(salt)
        self.verifier = BigUInt(Foundation.Data(Array(verifier)))
        self.privateKey = BigUInt(Foundation.Data(Array(privateKey)))
        // B = (k*v + g^b) mod N
        let gb = SRP6a.generator.power(self.privateKey, modulus: SRP6a.prime)
        let kv = (SRP6a.multiplier() * self.verifier) % SRP6a.prime
        self.publicKey = FoundationEmbedded.Data(SRP6a.padded((gb + kv) % SRP6a.prime))
        self.sessionKey = FoundationEmbedded.Data()
    }

    public mutating func processClientPublicKey(
        _ clientPublicKey: FoundationEmbedded.Data
    ) throws(HAPError) {
        let clientKeyBytes = Array(clientPublicKey)
        guard clientKeyBytes.count <= SRP6a.primeByteCount else {
            throw .invalidData
        }
        let clientKey = BigUInt(Foundation.Data(clientKeyBytes))
        // Refer to RFC 5054, Section 2.5.4: fail if A mod N == 0.
        guard clientKey % SRP6a.prime != 0 else {
            throw .invalidData
        }
        let paddedClientKey = SRP6a.padded(clientKey)
        // u = H(PAD(A) ‖ PAD(B))
        let scrambling = BigUInt(
            Foundation.Data(SRP6a.sha512([paddedClientKey, Array(publicKey)]))
        )
        // S = (A * v^u)^b mod N
        let base = (clientKey * verifier.power(scrambling, modulus: SRP6a.prime)) % SRP6a.prime
        let premasterSecret = base.power(privateKey, modulus: SRP6a.prime)
        // K = H(S), leading zeros stripped (minimal serialization).
        self.sessionKey = FoundationEmbedded.Data(
            SRP6a.sha512([Array(premasterSecret.serialize())])
        )
        self.clientPublicKey = paddedClientKey
    }

    public mutating func verifyClientProof(
        _ clientProof: FoundationEmbedded.Data
    ) throws(HAPError) -> FoundationEmbedded.Data {
        guard let paddedClientKey = clientPublicKey, !sessionKey.isEmpty else {
            throw .invalidState
        }
        let key = Array(sessionKey)
        // M1 = H((H(N) ⊕ H(g)) ‖ H(I) ‖ s ‖ A ‖ B ‖ K)
        let primeHash = SRP6a.sha512([SRPGroup.primeBytes])
        let generatorHash = SRP6a.sha512([SRPGroup.generatorBytes])
        let groupHash = zip(primeHash, generatorHash).map(^)
        let usernameHash = SRP6a.sha512([username])
        let expected = SRP6a.sha512([
            groupHash,
            usernameHash,
            salt,
            SRP6a.stripped(paddedClientKey),
            SRP6a.stripped(Array(publicKey)),
            key
        ])
        // Constant-time comparison.
        let proof = Array(clientProof)
        guard proof.count == expected.count else {
            throw .notAuthorized
        }
        var difference: UInt8 = 0
        for index in expected.indices {
            difference |= expected[index] ^ proof[index]
        }
        guard difference == 0 else {
            throw .notAuthorized
        }
        // M2 = H(PAD(A) ‖ M1 ‖ K)
        return FoundationEmbedded.Data(SRP6a.sha512([paddedClientKey, expected, key]))
    }
}
