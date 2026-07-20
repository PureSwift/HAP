import Testing
import BigInt
import Foundation
import FoundationEmbedded
import HAP
@testable import HAPCryptoKit

/// End-to-end Pair Setup and Pair Verify exchanges between the server state machines and a
/// simulated controller using the same primitives.
@Suite
struct PairingSessionTests {

    let provider = SwiftCryptoProvider()
    let setupCode = "101-48-005"
    let accessoryIdentifier = "AA:BB:CC:DD:EE:FF"
    let controllerIdentifier = "E9E23DA1-3DDC-4A54-9F46-8663FB4CE1F1"

    var setupSalt: FoundationEmbedded.Data {
        FoundationEmbedded.Data(CryptoTestVectors.srpSalt)
    }

    // MARK: Controller-side SRP

    struct ControllerSRP {
        let publicKey: [UInt8]   // A, padded
        let sessionKey: [UInt8]  // K
        let proof: [UInt8]       // M1
    }

    func controllerSRP(
        password: String,
        salt: [UInt8],
        serverPublicKey: [UInt8]
    ) -> ControllerSRP {
        let username = Array("Pair-Setup".utf8)
        let privateKey = BigUInt(Foundation.Data([UInt8](repeating: 0x42, count: 32)))
        let publicKey = SRP6a.padded(SRP6a.generator.power(privateKey, modulus: SRP6a.prime))
        let scrambling = BigUInt(
            Foundation.Data(SRP6a.sha512([publicKey, serverPublicKey]))
        )
        let x = SRP6a.passwordHash(
            username: username,
            password: Array(password.utf8),
            salt: salt
        )
        let serverKey = BigUInt(Foundation.Data(serverPublicKey))
        let gx = SRP6a.generator.power(x, modulus: SRP6a.prime)
        let base = (serverKey + SRP6a.prime - (SRP6a.multiplier() * gx) % SRP6a.prime) % SRP6a.prime
        let secret = base.power(privateKey + scrambling * x, modulus: SRP6a.prime)
        let sessionKey = SRP6a.sha512([Array(secret.serialize())])
        // M1 = H((H(N) ⊕ H(g)) ‖ H(I) ‖ s ‖ A ‖ B ‖ K)
        let groupHash = zip(
            SRP6a.sha512([SRPGroup.primeBytes]),
            SRP6a.sha512([SRPGroup.generatorBytes])
        ).map(^)
        let proof = SRP6a.sha512([
            groupHash,
            SRP6a.sha512([username]),
            salt,
            SRP6a.stripped(publicKey),
            SRP6a.stripped(serverPublicKey),
            sessionKey
        ])
        return ControllerSRP(publicKey: publicKey, sessionKey: sessionKey, proof: proof)
    }

    func makePairSetupServer(secretKey: FoundationEmbedded.Data) -> PairSetupServer<SwiftCryptoProvider> {
        PairSetupServer(
            crypto: provider,
            accessoryIdentifier: accessoryIdentifier,
            accessoryLongTermSecretKey: secretKey,
            setupSalt: setupSalt,
            setupVerifier: provider.srpVerifier(
                username: "Pair-Setup",
                password: setupCode,
                salt: setupSalt
            )
        )
    }

    // MARK: Pair Setup

    @Test
    func pairSetup() throws {
        let accessorySecretKey = provider.makeEd25519PrivateKey()
        var server = makePairSetupServer(secretKey: accessorySecretKey)

        // M1: SRP Start Request.
        var m1 = PairingTLV()
        m1.append(integer: 1, for: .state)
        m1.append(integer: UInt64(PairingMethod.pairSetup.rawValue), for: .method)
        let m2 = server.handle(m1)
        #expect(m2.state == 2)
        #expect(m2.error == nil)
        let serverPublicKey = try #require(m2[.publicKey])
        #expect(m2[.salt] == setupSalt)
        #expect(server.state == .waitingForVerifyRequest)

        // M3: SRP Verify Request.
        let client = controllerSRP(
            password: setupCode,
            salt: CryptoTestVectors.srpSalt,
            serverPublicKey: Array(serverPublicKey)
        )
        var m3 = PairingTLV()
        m3.append(integer: 3, for: .state)
        m3.append(FoundationEmbedded.Data(client.publicKey), for: .publicKey)
        m3.append(FoundationEmbedded.Data(client.proof), for: .proof)
        let m4 = server.handle(m3)
        #expect(m4.state == 4)
        #expect(m4.error == nil)
        // Verify the server's proof: M2 = H(PAD(A) ‖ M1 ‖ K).
        let expectedServerProof = SRP6a.sha512([client.publicKey, client.proof, client.sessionKey])
        #expect(m4[.proof].map(Array.init) == expectedServerProof)

        // M5: Exchange Request with the controller's identity.
        let sessionKey = provider.hkdfSHA512(
            inputKeyMaterial: FoundationEmbedded.Data(client.sessionKey),
            salt: FoundationEmbedded.Data(Array("Pair-Setup-Encrypt-Salt".utf8)),
            info: FoundationEmbedded.Data(Array("Pair-Setup-Encrypt-Info".utf8)),
            outputByteCount: 32
        )
        let controllerSecretKey = provider.makeEd25519PrivateKey()
        let controllerPublicKey = provider.ed25519PublicKey(for: controllerSecretKey)
        let controllerX = provider.hkdfSHA512(
            inputKeyMaterial: FoundationEmbedded.Data(client.sessionKey),
            salt: FoundationEmbedded.Data(Array("Pair-Setup-Controller-Sign-Salt".utf8)),
            info: FoundationEmbedded.Data(Array("Pair-Setup-Controller-Sign-Info".utf8)),
            outputByteCount: 32
        )
        var controllerInfo = controllerX
        controllerInfo.append(contentsOf: Array(controllerIdentifier.utf8))
        controllerInfo.append(contentsOf: controllerPublicKey)
        var subTLV = PairingTLV()
        subTLV.append(string: controllerIdentifier, for: .identifier)
        subTLV.append(controllerPublicKey, for: .publicKey)
        subTLV.append(
            try provider.ed25519Signature(for: controllerInfo, privateKey: controllerSecretKey),
            for: .signature
        )
        var m5 = PairingTLV()
        m5.append(integer: 5, for: .state)
        m5.append(
            try provider.seal(
                subTLV.data,
                key: sessionKey,
                nonce: FoundationEmbedded.Data(Array("PS-Msg05".utf8)),
                authenticatedData: FoundationEmbedded.Data()
            ),
            for: .encryptedData
        )
        let m6 = server.handle(m5)
        #expect(m6.state == 6)
        #expect(m6.error == nil)
        #expect(server.state == .completed)

        // The server now knows the controller's pairing.
        let result = try #require(server.result)
        #expect(result.controllerIdentifier == controllerIdentifier)
        #expect(result.controllerLongTermPublicKey == controllerPublicKey)
        #expect(result.permissions == .admin)

        // M6 verification by the controller: decrypt and check the accessory's identity.
        let decrypted = try provider.open(
            try #require(m6[.encryptedData]),
            key: sessionKey,
            nonce: FoundationEmbedded.Data(Array("PS-Msg06".utf8)),
            authenticatedData: FoundationEmbedded.Data()
        )
        let accessoryTLV = try #require(PairingTLV(data: decrypted))
        #expect(accessoryTLV.string(for: .identifier) == accessoryIdentifier)
        let accessoryPublicKey = try #require(accessoryTLV[.publicKey])
        #expect(accessoryPublicKey == provider.ed25519PublicKey(for: accessorySecretKey))
        let accessoryX = provider.hkdfSHA512(
            inputKeyMaterial: FoundationEmbedded.Data(client.sessionKey),
            salt: FoundationEmbedded.Data(Array("Pair-Setup-Accessory-Sign-Salt".utf8)),
            info: FoundationEmbedded.Data(Array("Pair-Setup-Accessory-Sign-Info".utf8)),
            outputByteCount: 32
        )
        var accessoryInfo = accessoryX
        accessoryInfo.append(contentsOf: Array(accessoryIdentifier.utf8))
        accessoryInfo.append(contentsOf: accessoryPublicKey)
        #expect(provider.ed25519IsValidSignature(
            try #require(accessoryTLV[.signature]),
            for: accessoryInfo,
            publicKey: accessoryPublicKey
        ))
    }

    @Test
    func pairSetupRejectsWrongSetupCode() throws {
        var server = makePairSetupServer(secretKey: provider.makeEd25519PrivateKey())
        var m1 = PairingTLV()
        m1.append(integer: 1, for: .state)
        m1.append(integer: UInt64(PairingMethod.pairSetup.rawValue), for: .method)
        let m2 = server.handle(m1)
        let serverPublicKey = try #require(m2[.publicKey])

        // Controller uses the wrong setup code.
        let client = controllerSRP(
            password: "999-88-777",
            salt: CryptoTestVectors.srpSalt,
            serverPublicKey: Array(serverPublicKey)
        )
        var m3 = PairingTLV()
        m3.append(integer: 3, for: .state)
        m3.append(FoundationEmbedded.Data(client.publicKey), for: .publicKey)
        m3.append(FoundationEmbedded.Data(client.proof), for: .proof)
        let m4 = server.handle(m3)
        #expect(m4.state == 4)
        #expect(m4.error == .authentication)
        #expect(server.state == .failed)
        #expect(server.result == nil)
    }

    // MARK: Pair Verify

    @Test
    func pairVerify() throws {
        let accessorySecretKey = provider.makeEd25519PrivateKey()
        let accessoryPublicKey = provider.ed25519PublicKey(for: accessorySecretKey)
        let controllerSecretKey = provider.makeEd25519PrivateKey()
        let controllerPublicKey = provider.ed25519PublicKey(for: controllerSecretKey)

        var server = PairVerifyServer(
            crypto: provider,
            accessoryIdentifier: accessoryIdentifier,
            accessoryLongTermSecretKey: accessorySecretKey,
            controllerLongTermPublicKey: { [controllerIdentifier] identifier in
                identifier == controllerIdentifier ? controllerPublicKey : nil
            }
        )

        // M1: Verify Start Request with the controller's ephemeral key.
        let controllerEphemeralSecret = provider.makeCurve25519PrivateKey()
        let controllerEphemeralPublic = provider.curve25519PublicKey(for: controllerEphemeralSecret)
        var m1 = PairingTLV()
        m1.append(integer: 1, for: .state)
        m1.append(controllerEphemeralPublic, for: .publicKey)
        let m2 = server.handle(m1)
        #expect(m2.state == 2)
        #expect(m2.error == nil)

        // Controller verifies M2.
        let accessoryEphemeralPublic = try #require(m2[.publicKey])
        let sharedSecret = try provider.curve25519SharedSecret(
            privateKey: controllerEphemeralSecret,
            peerPublicKey: accessoryEphemeralPublic
        )
        let sessionKey = provider.hkdfSHA512(
            inputKeyMaterial: sharedSecret,
            salt: FoundationEmbedded.Data(Array("Pair-Verify-Encrypt-Salt".utf8)),
            info: FoundationEmbedded.Data(Array("Pair-Verify-Encrypt-Info".utf8)),
            outputByteCount: 32
        )
        let decrypted = try provider.open(
            try #require(m2[.encryptedData]),
            key: sessionKey,
            nonce: FoundationEmbedded.Data(Array("PV-Msg02".utf8)),
            authenticatedData: FoundationEmbedded.Data()
        )
        let accessoryTLV = try #require(PairingTLV(data: decrypted))
        #expect(accessoryTLV.string(for: .identifier) == accessoryIdentifier)
        var accessoryInfo = accessoryEphemeralPublic
        accessoryInfo.append(contentsOf: Array(accessoryIdentifier.utf8))
        accessoryInfo.append(contentsOf: controllerEphemeralPublic)
        #expect(provider.ed25519IsValidSignature(
            try #require(accessoryTLV[.signature]),
            for: accessoryInfo,
            publicKey: accessoryPublicKey
        ))

        // M3: Verify Finish Request with the controller's identity.
        var controllerInfo = controllerEphemeralPublic
        controllerInfo.append(contentsOf: Array(controllerIdentifier.utf8))
        controllerInfo.append(contentsOf: accessoryEphemeralPublic)
        var subTLV = PairingTLV()
        subTLV.append(string: controllerIdentifier, for: .identifier)
        subTLV.append(
            try provider.ed25519Signature(for: controllerInfo, privateKey: controllerSecretKey),
            for: .signature
        )
        var m3 = PairingTLV()
        m3.append(integer: 3, for: .state)
        m3.append(
            try provider.seal(
                subTLV.data,
                key: sessionKey,
                nonce: FoundationEmbedded.Data(Array("PV-Msg03".utf8)),
                authenticatedData: FoundationEmbedded.Data()
            ),
            for: .encryptedData
        )
        let m4 = server.handle(m3)
        #expect(m4.state == 4)
        #expect(m4.error == nil)
        #expect(server.state == .completed)

        // Both sides share the same secret and derive the same channel keys.
        let result = try #require(server.result)
        #expect(result.controllerIdentifier == controllerIdentifier)
        #expect(result.sharedSecret == sharedSecret)
        #expect(result.sessionKey == sessionKey)
        let keys = result.controlChannelKeys(using: provider)
        #expect(keys.accessoryToController == provider.hkdfSHA512(
            inputKeyMaterial: sharedSecret,
            salt: FoundationEmbedded.Data(Array("Control-Salt".utf8)),
            info: FoundationEmbedded.Data(Array("Control-Read-Encryption-Key".utf8)),
            outputByteCount: 32
        ))
        #expect(keys.accessoryToController != keys.controllerToAccessory)
    }

    @Test
    func pairVerifyRejectsUnknownController() throws {
        var server = PairVerifyServer(
            crypto: provider,
            accessoryIdentifier: accessoryIdentifier,
            accessoryLongTermSecretKey: provider.makeEd25519PrivateKey(),
            controllerLongTermPublicKey: { _ in nil }  // no pairings
        )
        let controllerEphemeralSecret = provider.makeCurve25519PrivateKey()
        var m1 = PairingTLV()
        m1.append(integer: 1, for: .state)
        m1.append(provider.curve25519PublicKey(for: controllerEphemeralSecret), for: .publicKey)
        let m2 = server.handle(m1)
        let sharedSecret = try provider.curve25519SharedSecret(
            privateKey: controllerEphemeralSecret,
            peerPublicKey: try #require(m2[.publicKey])
        )
        let sessionKey = provider.hkdfSHA512(
            inputKeyMaterial: sharedSecret,
            salt: FoundationEmbedded.Data(Array("Pair-Verify-Encrypt-Salt".utf8)),
            info: FoundationEmbedded.Data(Array("Pair-Verify-Encrypt-Info".utf8)),
            outputByteCount: 32
        )
        var subTLV = PairingTLV()
        subTLV.append(string: "unknown-controller", for: .identifier)
        subTLV.append(FoundationEmbedded.Data([UInt8](repeating: 0, count: 64)), for: .signature)
        var m3 = PairingTLV()
        m3.append(integer: 3, for: .state)
        m3.append(
            try provider.seal(
                subTLV.data,
                key: sessionKey,
                nonce: FoundationEmbedded.Data(Array("PV-Msg03".utf8)),
                authenticatedData: FoundationEmbedded.Data()
            ),
            for: .encryptedData
        )
        let m4 = server.handle(m3)
        #expect(m4.state == 4)
        #expect(m4.error == .authentication)
        #expect(server.state == .failed)
    }
}
