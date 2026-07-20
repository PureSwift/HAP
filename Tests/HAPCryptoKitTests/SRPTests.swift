import Testing
import BigInt
import Foundation
import HAP
@testable import HAPCryptoKit

/// SRP-6a tests against the test vectors of HAP Specification R2, Section 5.5.2.
@Suite
struct SRPTests {

    func makeServer() -> SRP6aServer {
        SRP6aServer(
            username: CryptoTestVectors.srpUsername,
            salt: Data(CryptoTestVectors.srpSalt),
            verifier: Data(CryptoTestVectors.srpVerifier),
            privateKey: Data(CryptoTestVectors.srpServerPrivateKey)
        )
    }

    @Test
    func verifier() {
        let verifier = SRP6a.verifier(
            username: Array(CryptoTestVectors.srpUsername.utf8),
            password: Array(CryptoTestVectors.srpPassword.utf8),
            salt: CryptoTestVectors.srpSalt
        )
        #expect(verifier == CryptoTestVectors.srpVerifier)
    }

    @Test
    func serverPublicKey() {
        let server = makeServer()
        #expect(Array(server.publicKey) == CryptoTestVectors.srpServerPublicKey)
    }

    @Test
    func scramblingParameter() {
        let scrambling = SRP6a.sha512([
            CryptoTestVectors.srpClientPublicKey,
            CryptoTestVectors.srpServerPublicKey
        ])
        #expect(scrambling == CryptoTestVectors.srpScramblingParameter)
    }

    @Test
    func sessionKey() throws {
        var server = makeServer()
        try server.processClientPublicKey(
            Data(CryptoTestVectors.srpClientPublicKey)
        )
        #expect(Array(server.sessionKey) == CryptoTestVectors.srpSessionKey)
    }

    @Test
    func proofs() throws {
        var server = makeServer()
        try server.processClientPublicKey(
            Data(CryptoTestVectors.srpClientPublicKey)
        )
        let serverProof = try server.verifyClientProof(
            Data(CryptoTestVectors.srpProofM1)
        )
        #expect(Array(serverProof) == CryptoTestVectors.srpProofM2)
    }

    @Test
    func rejectsInvalidProof() throws {
        var server = makeServer()
        try server.processClientPublicKey(
            Data(CryptoTestVectors.srpClientPublicKey)
        )
        var wrongProof = CryptoTestVectors.srpProofM1
        wrongProof[0] ^= 0xFF
        #expect(throws: HAPError.notAuthorized) {
            try server.verifyClientProof(Data(wrongProof))
        }
    }

    @Test
    func rejectsIllegalClientPublicKey() {
        var server = makeServer()
        // A mod N == 0 must be rejected (RFC 5054, Section 2.5.4).
        #expect(throws: HAPError.invalidData) {
            try server.processClientPublicKey(Data(SRPGroup.primeBytes))
        }
        #expect(throws: HAPError.invalidData) {
            try server.processClientPublicKey(Data([0x00]))
        }
    }

    @Test
    func rejectsProofBeforeClientKey() {
        var server = makeServer()
        #expect(throws: HAPError.invalidState) {
            try server.verifyClientProof(Data(CryptoTestVectors.srpProofM1))
        }
    }

    /// End-to-end exchange with a random server private key, exercising both sides.
    @Test
    func randomExchange() throws {
        let provider = SwiftCryptoProvider()
        let salt = Data(CryptoTestVectors.srpSalt)
        let verifier = provider.srpVerifier(
            username: "Pair-Setup",
            password: "101-48-005",
            salt: salt
        )
        var server = try provider.makeSRPServer(
            username: "Pair-Setup",
            salt: salt,
            verifier: verifier
        )

        // Client side (computed manually with the same primitives).
        let clientPrivateKey = BigUIntFromBytes([UInt8](repeating: 0x42, count: 32))
        let clientPublicKey = SRP6a.padded(
            SRP6a.generator.power(clientPrivateKey, modulus: SRP6a.prime)
        )
        try server.processClientPublicKey(Data(clientPublicKey))

        // Client computes the same session key.
        let scrambling = BigUIntFromBytes(
            SRP6a.sha512([clientPublicKey, Array(server.publicKey)])
        )
        let x = SRP6a.passwordHash(
            username: Array("Pair-Setup".utf8),
            password: Array("101-48-005".utf8),
            salt: CryptoTestVectors.srpSalt
        )
        let serverKey = BigUIntFromBytes(Array(server.publicKey))
        let k = SRP6a.multiplier()
        // S = (B - k*g^x)^(a + u*x) mod N
        let gx = SRP6a.generator.power(x, modulus: SRP6a.prime)
        let base = (serverKey + SRP6a.prime - (k * gx) % SRP6a.prime) % SRP6a.prime
        let secret = base.power(clientPrivateKey + scrambling * x, modulus: SRP6a.prime)
        let clientSessionKey = SRP6a.sha512([Array(secret.serialize())])
        #expect(Array(server.sessionKey) == clientSessionKey)
    }
}

private func BigUIntFromBytes(_ bytes: [UInt8]) -> BigUInt {
    BigUInt(Foundation.Data(bytes))
}
