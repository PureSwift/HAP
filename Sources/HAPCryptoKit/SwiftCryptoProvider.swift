import BigInt
import Crypto
import Foundation
import FoundationEmbedded
import HAP

/// The reference ``CryptoProvider`` for hosted platforms, backed by swift-crypto.
public struct SwiftCryptoProvider: CryptoProvider {

    public typealias SRP = SRP6aServer

    public init() {}

    // MARK: SHA-512

    public func sha512(_ message: FoundationEmbedded.Data) -> FoundationEmbedded.Data {
        FoundationEmbedded.Data(SHA512.hash(data: Foundation.Data(Array(message))))
    }

    // MARK: HKDF-SHA-512

    public func hkdfSHA512(
        inputKeyMaterial: FoundationEmbedded.Data,
        salt: FoundationEmbedded.Data,
        info: FoundationEmbedded.Data,
        outputByteCount: Int
    ) -> FoundationEmbedded.Data {
        let key = HKDF<SHA512>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Foundation.Data(Array(inputKeyMaterial))),
            salt: Foundation.Data(Array(salt)),
            info: Foundation.Data(Array(info)),
            outputByteCount: outputByteCount
        )
        return key.withUnsafeBytes { FoundationEmbedded.Data(Array($0)) }
    }

    // MARK: ChaCha20-Poly1305

    public func seal(
        _ message: FoundationEmbedded.Data,
        key: FoundationEmbedded.Data,
        nonce: FoundationEmbedded.Data,
        authenticatedData: FoundationEmbedded.Data
    ) throws(HAPError) -> FoundationEmbedded.Data {
        guard let nonceBytes = Self.normalizedNonce(Array(nonce)) else {
            throw .invalidData
        }
        do {
            let sealedBox = try ChaChaPoly.seal(
                Foundation.Data(Array(message)),
                using: SymmetricKey(data: Foundation.Data(Array(key))),
                nonce: ChaChaPoly.Nonce(data: Foundation.Data(nonceBytes)),
                authenticating: Foundation.Data(Array(authenticatedData))
            )
            return FoundationEmbedded.Data(Array(sealedBox.ciphertext) + Array(sealedBox.tag))
        } catch {
            throw .invalidData
        }
    }

    public func open(
        _ ciphertext: FoundationEmbedded.Data,
        key: FoundationEmbedded.Data,
        nonce: FoundationEmbedded.Data,
        authenticatedData: FoundationEmbedded.Data
    ) throws(HAPError) -> FoundationEmbedded.Data {
        guard let nonceBytes = Self.normalizedNonce(Array(nonce)),
              ciphertext.count >= 16
        else { throw .invalidData }
        let bytes = Array(ciphertext)
        do {
            let sealedBox = try ChaChaPoly.SealedBox(
                nonce: ChaChaPoly.Nonce(data: Foundation.Data(nonceBytes)),
                ciphertext: Foundation.Data(bytes[..<(bytes.count - 16)]),
                tag: Foundation.Data(bytes[(bytes.count - 16)...])
            )
            let message = try ChaChaPoly.open(
                sealedBox,
                using: SymmetricKey(data: Foundation.Data(Array(key))),
                authenticating: Foundation.Data(Array(authenticatedData))
            )
            return FoundationEmbedded.Data(message)
        } catch {
            throw .notAuthorized
        }
    }

    /// HAP uses 64-bit nonces, zero-padded in the most significant bytes to the 96-bit
    /// nonce required by RFC 8439.
    static func normalizedNonce(_ nonce: [UInt8]) -> [UInt8]? {
        switch nonce.count {
        case 8: return [0, 0, 0, 0] + nonce
        case 12: return nonce
        default: return nil
        }
    }

    // MARK: Ed25519

    public func makeEd25519PrivateKey() -> FoundationEmbedded.Data {
        FoundationEmbedded.Data(Curve25519.Signing.PrivateKey().rawRepresentation)
    }

    public func ed25519PublicKey(for privateKey: FoundationEmbedded.Data) -> FoundationEmbedded.Data {
        let key = try! Curve25519.Signing.PrivateKey(
            rawRepresentation: Foundation.Data(Array(privateKey))
        )
        return FoundationEmbedded.Data(key.publicKey.rawRepresentation)
    }

    public func ed25519Signature(
        for message: FoundationEmbedded.Data,
        privateKey: FoundationEmbedded.Data
    ) throws(HAPError) -> FoundationEmbedded.Data {
        do {
            let key = try Curve25519.Signing.PrivateKey(
                rawRepresentation: Foundation.Data(Array(privateKey))
            )
            return FoundationEmbedded.Data(try key.signature(for: Foundation.Data(Array(message))))
        } catch {
            throw .invalidData
        }
    }

    public func ed25519IsValidSignature(
        _ signature: FoundationEmbedded.Data,
        for message: FoundationEmbedded.Data,
        publicKey: FoundationEmbedded.Data
    ) -> Bool {
        guard let key = try? Curve25519.Signing.PublicKey(
            rawRepresentation: Foundation.Data(Array(publicKey))
        ) else { return false }
        return key.isValidSignature(
            Foundation.Data(Array(signature)),
            for: Foundation.Data(Array(message))
        )
    }

    // MARK: X25519

    public func makeCurve25519PrivateKey() -> FoundationEmbedded.Data {
        FoundationEmbedded.Data(Curve25519.KeyAgreement.PrivateKey().rawRepresentation)
    }

    public func curve25519PublicKey(for privateKey: FoundationEmbedded.Data) -> FoundationEmbedded.Data {
        let key = try! Curve25519.KeyAgreement.PrivateKey(
            rawRepresentation: Foundation.Data(Array(privateKey))
        )
        return FoundationEmbedded.Data(key.publicKey.rawRepresentation)
    }

    public func curve25519SharedSecret(
        privateKey: FoundationEmbedded.Data,
        peerPublicKey: FoundationEmbedded.Data
    ) throws(HAPError) -> FoundationEmbedded.Data {
        do {
            let key = try Curve25519.KeyAgreement.PrivateKey(
                rawRepresentation: Foundation.Data(Array(privateKey))
            )
            let peer = try Curve25519.KeyAgreement.PublicKey(
                rawRepresentation: Foundation.Data(Array(peerPublicKey))
            )
            let secret = try key.sharedSecretFromKeyAgreement(with: peer)
            return secret.withUnsafeBytes { FoundationEmbedded.Data(Array($0)) }
        } catch {
            throw .invalidData
        }
    }

    // MARK: SRP-6a

    public func srpVerifier(
        username: String,
        password: String,
        salt: FoundationEmbedded.Data
    ) -> FoundationEmbedded.Data {
        FoundationEmbedded.Data(SRP6a.verifier(
            username: Array(username.utf8),
            password: Array(password.utf8),
            salt: Array(salt)
        ))
    }

    public func makeSRPServer(
        username: String,
        salt: FoundationEmbedded.Data,
        verifier: FoundationEmbedded.Data
    ) throws(HAPError) -> SRP6aServer {
        var generator = SystemRandomNumberGenerator()
        let privateKey = (0 ..< 32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return SRP6aServer(
            username: username,
            salt: salt,
            verifier: verifier,
            privateKey: FoundationEmbedded.Data(privateKey)
        )
    }
}
