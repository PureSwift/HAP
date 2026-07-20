import Testing
@testable import HAP

@Suite
struct BLEBroadcastTests {

    // MARK: Global State Number

    @Test
    func gsnStartsAtOne() {
        let gsn = BLEAccessoryServerGSN.initial
        #expect(gsn.gsn == 1)
        #expect(!gsn.didIncrement)
    }

    @Test
    func gsnIncrementsOncePerCycle() {
        var gsn = BLEAccessoryServerGSN.initial
        var changed = gsn.increment()
        #expect(changed)
        #expect(gsn.gsn == 2)
        #expect(gsn.didIncrement)

        // Further increments in the same connect / disconnect cycle are suppressed.
        changed = gsn.increment()
        #expect(!changed)
        #expect(gsn.gsn == 2)

        gsn.endCycle()
        changed = gsn.increment()
        #expect(changed)
        #expect(gsn.gsn == 3)
    }

    /// The GSN has a range of 1 – 65535 and wraps to 1 on overflow.
    @Test
    func gsnWrapsToOne() throws {
        var gsn = try #require(BLEAccessoryServerGSN(gsn: .max, didIncrement: false))
        gsn.increment()
        #expect(gsn.gsn == 1)
    }

    @Test
    func gsnRejectsZero() {
        #expect(BLEAccessoryServerGSN(gsn: 0, didIncrement: false) == nil)
        #expect(BLEAccessoryServerGSN(gsn: 1, didIncrement: false) != nil)
    }

    // MARK: Broadcast Intervals

    @Test
    func broadcastIntervals() {
        #expect(BLEBroadcastInterval.milliseconds20.rawValue == 0x01)
        #expect(BLEBroadcastInterval.milliseconds1280.rawValue == 0x02)
        #expect(BLEBroadcastInterval.milliseconds2560.rawValue == 0x03)
        #expect(BLEBroadcastInterval.default == .milliseconds20)
        #expect(BLEBroadcastInterval.milliseconds1280.milliseconds == 1280)
        #expect(BLEBroadcastInterval(rawValue: 0x04) == nil)  // reserved
        #expect(BLECharacteristicConfigurationProperties.broadcastNotification.rawValue == 0x0001)
    }

    // MARK: Broadcast Parameters

    let crypto = MockHKDFProvider()

    @Test
    func emptyParameters() {
        let parameters = BLEBroadcastParameters()
        #expect(parameters.key == nil)
        #expect(parameters.keyExpirationGSN == nil)
        #expect(!parameters.hasValidKey(at: 1))
    }

    @Test
    func generatesKey() {
        var parameters = BLEBroadcastParameters()
        parameters.generateKey(
            sharedSecret: Data([UInt8](repeating: 0x11, count: 32)),
            controllerPublicKey: Data([UInt8](repeating: 0x22, count: 32)),
            gsn: 1,
            using: crypto
        )
        #expect(parameters.key?.count == 32)
        // The key is derived with the "Broadcast-Encryption-Key" info string, salted
        // with the controller's long-term public key.
        #expect(crypto.lastInfo == Data(Array("Broadcast-Encryption-Key".utf8)))
        #expect(crypto.lastSalt == Data([UInt8](repeating: 0x22, count: 32)))
        #expect(crypto.lastInputKeyMaterial == Data([UInt8](repeating: 0x11, count: 32)))
        #expect(parameters.hasValidKey(at: 1))
    }

    /// The key expires after 32,767 GSN increments (§7.4.7.4).
    @Test
    func keyExpiration() {
        var parameters = BLEBroadcastParameters()
        parameters.generateKey(
            sharedSecret: Data([UInt8](repeating: 1, count: 32)),
            controllerPublicKey: Data([UInt8](repeating: 2, count: 32)),
            gsn: 1,
            using: crypto
        )
        #expect(parameters.keyExpirationGSN == 32_767)
        #expect(parameters.hasValidKey(at: 1))
        #expect(parameters.hasValidKey(at: 32_767))
        #expect(!parameters.hasValidKey(at: 32_768))
    }

    /// The expiration value wraps within the 1 – 65535 GSN range.
    @Test
    func keyExpirationWraps() {
        #expect(BLEBroadcastParameters.expirationGSN(for: 1) == 32_767)
        // The last value that does not wrap, and the first that does — wrapping skips 0,
        // which is not a valid global state number.
        #expect(BLEBroadcastParameters.expirationGSN(for: 32_769) == 65_535)
        #expect(BLEBroadcastParameters.expirationGSN(for: 32_770) == 1)
        // Wrapping past the maximum resumes from the low end of the range.
        let wrapped = BLEBroadcastParameters.expirationGSN(for: 40_000)
        #expect(wrapped == 40_000 + 32_766 - 65_535)
        #expect(wrapped != 0)

        var parameters = BLEBroadcastParameters()
        parameters.generateKey(
            sharedSecret: Data([UInt8](repeating: 1, count: 32)),
            controllerPublicKey: Data([UInt8](repeating: 2, count: 32)),
            gsn: 60_000,
            using: crypto
        )
        #expect(parameters.hasValidKey(at: 60_000))
        #expect(parameters.hasValidKey(at: 100))  // after wrapping
    }

    @Test
    func removeKey() {
        var parameters = BLEBroadcastParameters()
        parameters.generateKey(
            sharedSecret: Data([UInt8](repeating: 1, count: 32)),
            controllerPublicKey: Data([UInt8](repeating: 2, count: 32)),
            gsn: 5,
            using: crypto
        )
        parameters.removeKey()
        #expect(parameters.key == nil)
        #expect(!parameters.hasValidKey(at: 5))
    }

    // MARK: Storage

    @Test
    func storageRoundtrip() throws {
        var parameters = BLEBroadcastParameters()
        parameters.generateKey(
            sharedSecret: Data([UInt8](repeating: 1, count: 32)),
            controllerPublicKey: Data([UInt8](repeating: 2, count: 32)),
            gsn: 7,
            using: crypto
        )
        parameters.advertisingID = Data([0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6])

        let data = parameters.storageData
        #expect(data.count == BLEBroadcastParameters.storageSize)
        #expect(data.count == 41)
        let decoded = try #require(BLEBroadcastParameters(storageData: data))
        #expect(decoded == parameters)
    }

    @Test
    func storageRoundtripWithoutKey() throws {
        var parameters = BLEBroadcastParameters()
        parameters.advertisingID = Data([1, 2, 3, 4, 5, 6])
        let decoded = try #require(BLEBroadcastParameters(storageData: parameters.storageData))
        #expect(decoded.key == nil)
        #expect(decoded.keyExpirationGSN == nil)
        #expect(decoded.advertisingID == parameters.advertisingID)

        let empty = try #require(BLEBroadcastParameters(storageData: BLEBroadcastParameters().storageData))
        #expect(empty == BLEBroadcastParameters())
    }

    @Test
    func storageRejectsWrongSize() {
        #expect(BLEBroadcastParameters(storageData: Data([0, 0])) == nil)
        #expect(BLEBroadcastParameters(storageData: Data()) == nil)
    }
}

// MARK: -

/// A crypto provider that records HKDF inputs and returns a deterministic key.
final class MockHKDFProvider: CryptoProvider, @unchecked Sendable {

    typealias SRP = MockSRPServer

    private(set) var lastInputKeyMaterial: Data?
    private(set) var lastSalt: Data?
    private(set) var lastInfo: Data?

    func hkdfSHA512(
        inputKeyMaterial: Data,
        salt: Data,
        info: Data,
        outputByteCount: Int
    ) -> Data {
        lastInputKeyMaterial = inputKeyMaterial
        lastSalt = salt
        lastInfo = info
        return Data([UInt8](repeating: 0xAB, count: outputByteCount))
    }

    func sha512(_ message: Data) -> Data { fatalError("Not implemented") }

    func seal(_ message: Data, key: Data, nonce: Data, authenticatedData: Data) throws(HAPError) -> Data {
        fatalError("Not implemented")
    }

    func open(_ ciphertext: Data, key: Data, nonce: Data, authenticatedData: Data) throws(HAPError) -> Data {
        fatalError("Not implemented")
    }

    func makeEd25519PrivateKey() -> Data { fatalError("Not implemented") }
    func ed25519PublicKey(for privateKey: Data) -> Data { fatalError("Not implemented") }

    func ed25519Signature(for message: Data, privateKey: Data) throws(HAPError) -> Data {
        fatalError("Not implemented")
    }

    func ed25519IsValidSignature(_ signature: Data, for message: Data, publicKey: Data) -> Bool {
        fatalError("Not implemented")
    }

    func makeCurve25519PrivateKey() -> Data { fatalError("Not implemented") }
    func curve25519PublicKey(for privateKey: Data) -> Data { fatalError("Not implemented") }

    func curve25519SharedSecret(privateKey: Data, peerPublicKey: Data) throws(HAPError) -> Data {
        fatalError("Not implemented")
    }

    func srpVerifier(username: String, password: String, salt: Data) -> Data {
        fatalError("Not implemented")
    }

    func makeSRPServer(username: String, salt: Data, verifier: Data) throws(HAPError) -> MockSRPServer {
        fatalError("Not implemented")
    }
}
