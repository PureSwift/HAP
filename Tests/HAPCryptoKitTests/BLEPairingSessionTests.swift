import Testing
import TLVCoding
@testable import HAP
@testable import HAPCryptoKit

/// Pairing over Bluetooth LE: the pairing TLVs travel through HAP PDU write requests.
@Suite
struct BLEPairingSessionTests {

    let provider = SwiftCryptoProvider()
    let accessoryIdentifier = "AA:BB:CC:DD:EE:FF"

    func makeSession(
        controllerLookup: @escaping (String) -> Data? = { _ in nil }
    ) -> BLEPairingSession<SwiftCryptoProvider> {
        BLEPairingSession(
            crypto: provider,
            configuration: .init(
                accessoryIdentifier: accessoryIdentifier,
                accessoryLongTermSecretKey: provider.makeEd25519PrivateKey(),
                setupSalt: Data(CryptoTestVectors.srpSalt),
                setupVerifier: provider.srpVerifier(
                    username: "Pair-Setup",
                    password: "101-48-005",
                    salt: Data(CryptoTestVectors.srpSalt)
                ),
                controllerLongTermPublicKey: controllerLookup
            )
        )
    }

    /// Wraps a pairing TLV in a write request PDU, fragmenting the value parameter.
    func writeRequest(_ message: PairingTLV, iid: UInt16 = 0x22, tid: UInt8 = 0x11) -> BLEPDURequest {
        let value = Array(message.data)
        var body = TLVContainer()
        var offset = 0
        repeat {
            let end = min(offset + 255, value.count)
            body.items.append(TLVItem(
                type: BLEPDUParamType.value.typeCode,
                value: .init(value[offset ..< end])
            ))
            offset = end
        } while offset < value.count
        return BLEPDURequest(
            opcode: .characteristicWrite,
            transactionID: tid,
            instanceID: iid,
            body: Data(body.data)
        )
    }

    /// Extracts the pairing TLV from a response PDU body.
    func pairingTLV(from response: BLEPDUResponse) throws -> PairingTLV {
        let body = try #require(response.body)
        let container = try #require(TLVContainer(data: .init(body)))
        var value = [UInt8]()
        for item in container.items where item.type == BLEPDUParamType.value.typeCode {
            value.append(contentsOf: item.value)
        }
        return try #require(PairingTLV(data: Data(value)))
    }

    @Test
    func pairSetupOverPDUs() throws {
        var session = makeSession()

        // M1 (SRP Start Request) as a PDU write.
        var m1 = PairingTLV()
        m1.append(integer: 1, for: .state)
        m1.append(integer: UInt64(PairingMethod.pairSetup.rawValue), for: .method)
        let m2Response = session.handlePairSetupWrite(writeRequest(m1))
        #expect(m2Response.status == .success)
        #expect(m2Response.transactionID == 0x11)
        let m2 = try pairingTLV(from: m2Response)
        #expect(m2.state == 2)
        #expect(m2.error == nil)
        // The 384-byte SRP public key survives the fragmented value parameter.
        #expect(m2[.publicKey]?.count == 384)
        #expect(m2[.salt]?.count == 16)
        #expect(session.pairSetupResult == nil)
    }

    @Test
    func pairSetupFailureResetsSession() throws {
        var session = makeSession()
        var m1 = PairingTLV()
        m1.append(integer: 1, for: .state)
        m1.append(integer: UInt64(PairingMethod.pairSetup.rawValue), for: .method)
        _ = session.handlePairSetupWrite(writeRequest(m1))

        // A garbage M3 fails the exchange...
        var badM3 = PairingTLV()
        badM3.append(integer: 3, for: .state)
        badM3.append(Data([1, 2, 3]), for: .publicKey)
        badM3.append(Data([UInt8](repeating: 0, count: 64)), for: .proof)
        let failure = try pairingTLV(from: session.handlePairSetupWrite(writeRequest(badM3)))
        #expect(failure.error != nil)

        // ...and a fresh M1 afterwards starts a new session successfully.
        let restarted = try pairingTLV(from: session.handlePairSetupWrite(writeRequest(m1)))
        #expect(restarted.state == 2)
        #expect(restarted.error == nil)
    }

    @Test
    func pairVerifyOverPDUs() throws {
        // A controller paired out-of-band.
        let controllerSecretKey = provider.makeEd25519PrivateKey()
        let controllerPublicKey = provider.ed25519PublicKey(for: controllerSecretKey)
        let controllerIdentifier = "F1E2D3C4-0000-4A54-9F46-8663FB4CE1F1"
        var session = makeSession(controllerLookup: { identifier in
            identifier == controllerIdentifier ? controllerPublicKey : nil
        })

        // M1: Verify Start.
        let controllerEphemeralSecret = provider.makeCurve25519PrivateKey()
        let controllerEphemeralPublic = provider.curve25519PublicKey(for: controllerEphemeralSecret)
        var m1 = PairingTLV()
        m1.append(integer: 1, for: .state)
        m1.append(controllerEphemeralPublic, for: .publicKey)
        let m2 = try pairingTLV(from: session.handlePairVerifyWrite(writeRequest(m1)))
        #expect(m2.state == 2)
        #expect(m2.error == nil)
        #expect(session.pairVerifyResult == nil)

        // Controller side: derive the session key and answer M3.
        let accessoryEphemeralPublic = try #require(m2[.publicKey])
        let sharedSecret = try provider.curve25519SharedSecret(
            privateKey: controllerEphemeralSecret,
            peerPublicKey: accessoryEphemeralPublic
        )
        let sessionKey = provider.hkdfSHA512(
            inputKeyMaterial: sharedSecret,
            salt: Data(Array("Pair-Verify-Encrypt-Salt".utf8)),
            info: Data(Array("Pair-Verify-Encrypt-Info".utf8)),
            outputByteCount: 32
        )
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
                nonce: Data(Array("PV-Msg03".utf8)),
                authenticatedData: Data()
            ),
            for: .encryptedData
        )
        let m4 = try pairingTLV(from: session.handlePairVerifyWrite(writeRequest(m3)))
        #expect(m4.state == 4)
        #expect(m4.error == nil)

        // The session is established and yields the shared secret for session security.
        let result = try #require(session.pairVerifyResult)
        #expect(result.controllerIdentifier == controllerIdentifier)
        #expect(result.sharedSecret == sharedSecret)
    }

    @Test
    func rejectsMalformedPDU() {
        var session = makeSession()
        // A write request without a body is not a valid pairing message.
        let response = session.handlePairSetupWrite(BLEPDURequest(
            opcode: .characteristicWrite,
            transactionID: 0x01,
            instanceID: 0x22
        ))
        #expect(response.status == .invalidRequest)
    }
}
