import FoundationEmbedded
@testable import HAP

/// A crypto provider for tests backed by canned known-answer values.
struct MockCryptoProvider: CryptoProvider {

    /// Canned SHA-512 digests, keyed by message.
    var sha512Digests: [Data: Data] = [:]

    func sha512(_ message: Data) -> Data {
        guard let digest = sha512Digests[message] else {
            fatalError("No canned SHA-512 digest for message")
        }
        return digest
    }

    func hkdfSHA512(inputKeyMaterial: Data, salt: Data, info: Data, outputByteCount: Int) -> Data {
        fatalError("Not implemented")
    }

    func seal(_ message: Data, key: Data, nonce: Data, authenticatedData: Data) throws(HAPError) -> Data {
        fatalError("Not implemented")
    }

    func open(_ ciphertext: Data, key: Data, nonce: Data, authenticatedData: Data) throws(HAPError) -> Data {
        fatalError("Not implemented")
    }

    func makeEd25519PrivateKey() -> Data {
        fatalError("Not implemented")
    }

    func ed25519PublicKey(for privateKey: Data) -> Data {
        fatalError("Not implemented")
    }

    func ed25519Signature(for message: Data, privateKey: Data) throws(HAPError) -> Data {
        fatalError("Not implemented")
    }

    func ed25519IsValidSignature(_ signature: Data, for message: Data, publicKey: Data) -> Bool {
        fatalError("Not implemented")
    }

    func makeCurve25519PrivateKey() -> Data {
        fatalError("Not implemented")
    }

    func curve25519PublicKey(for privateKey: Data) -> Data {
        fatalError("Not implemented")
    }

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

// MARK: -

struct MockSRPServer: SRPServer {

    var publicKey: Data { fatalError("Not implemented") }

    var sessionKey: Data { fatalError("Not implemented") }

    mutating func processClientPublicKey(_ clientPublicKey: Data) throws(HAPError) {
        fatalError("Not implemented")
    }

    mutating func verifyClientProof(_ clientProof: Data) throws(HAPError) -> Data {
        fatalError("Not implemented")
    }
}

// MARK: - Hex Parsing

extension Data {

    /// Creates data from a hexadecimal string.
    init?(hexString: String) {
        let characters = Array(hexString)
        guard characters.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(characters.count / 2)
        var index = 0
        while index < characters.count {
            guard let high = characters[index].hexDigitValue,
                  let low = characters[index + 1].hexDigitValue
            else { return nil }
            bytes.append(UInt8(high << 4 | low))
            index += 2
        }
        self.init(bytes)
    }
}
