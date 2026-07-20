import Testing
import HAP
@testable import HAPCryptoKit

/// Tests against the RFC test vectors used by the ADK's crypto test suite
/// (RFC 8032, RFC 7748, RFC 7539, HKDF-SHA-512).
@Suite
struct SwiftCryptoProviderTests {

    let provider = SwiftCryptoProvider()

    @Test
    func sha512() {
        let digest = provider.sha512(Data(Array("abc".utf8)))
        #expect(Array(digest) == CryptoTestVectors.sha512Hash)
    }

    @Test
    func hkdfSHA512() {
        let key = provider.hkdfSHA512(
            inputKeyMaterial: Data(CryptoTestVectors.hkdfIKM),
            salt: Data(CryptoTestVectors.hkdfSalt),
            info: Data(CryptoTestVectors.hkdfInfo),
            outputByteCount: CryptoTestVectors.hkdfOKM.count
        )
        #expect(Array(key) == CryptoTestVectors.hkdfOKM)
    }

    @Test
    func chaCha20Poly1305() throws {
        let sealed = try provider.seal(
            Data(Array(CryptoTestVectors.chacha20Poly1305Pt.utf8)),
            key: Data(CryptoTestVectors.chacha20Poly1305Key),
            nonce: Data(CryptoTestVectors.chacha20Poly1305Nonce),
            authenticatedData: Data(CryptoTestVectors.chacha20Poly1305Aad)
        )
        let expected = CryptoTestVectors.chacha20Poly1305Ct + CryptoTestVectors.chacha20Poly1305Tag
        #expect(Array(sealed) == expected)

        let opened = try provider.open(
            sealed,
            key: Data(CryptoTestVectors.chacha20Poly1305Key),
            nonce: Data(CryptoTestVectors.chacha20Poly1305Nonce),
            authenticatedData: Data(CryptoTestVectors.chacha20Poly1305Aad)
        )
        #expect(Array(opened) == Array(CryptoTestVectors.chacha20Poly1305Pt.utf8))
    }

    @Test
    func chaCha20Poly1305RejectsTamperedCiphertext() throws {
        let key = Data(CryptoTestVectors.chacha20Poly1305Key)
        let nonce = Data(CryptoTestVectors.chacha20Poly1305Nonce)
        var sealed = Array(try provider.seal(
            Data(Array(CryptoTestVectors.chacha20Poly1305Pt.utf8)),
            key: key,
            nonce: nonce,
            authenticatedData: Data()
        ))
        sealed[0] ^= 0xFF
        #expect(throws: HAPError.notAuthorized) {
            try provider.open(
                Data(sealed),
                key: key,
                nonce: nonce,
                authenticatedData: Data()
            )
        }
    }

    @Test
    func chaCha20Poly1305PadsEightByteNonce() throws {
        // HAP 64-bit nonces are zero-padded to 96 bits.
        let message = Data(Array("hello".utf8))
        let key = Data([UInt8](repeating: 0x11, count: 32))
        let sealedShort = try provider.seal(
            message,
            key: key,
            nonce: Data([1, 2, 3, 4, 5, 6, 7, 8]),
            authenticatedData: Data()
        )
        let sealedFull = try provider.seal(
            message,
            key: key,
            nonce: Data([0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8]),
            authenticatedData: Data()
        )
        #expect(sealedShort == sealedFull)
    }

    @Test
    func ed25519() throws {
        let privateKey = Data(CryptoTestVectors.ed25519Sk)
        #expect(Array(provider.ed25519PublicKey(for: privateKey)) == CryptoTestVectors.ed25519Pk)

        let message = Data(CryptoTestVectors.ed25519M)
        // CryptoKit produces randomized Ed25519 signatures, so the deterministic RFC 8032
        // signature vector cannot be compared byte-for-byte — but both must verify.
        let signature = try provider.ed25519Signature(for: message, privateKey: privateKey)
        #expect(provider.ed25519IsValidSignature(
            Data(CryptoTestVectors.ed25519Sig),
            for: message,
            publicKey: Data(CryptoTestVectors.ed25519Pk)
        ))
        #expect(provider.ed25519IsValidSignature(
            signature,
            for: message,
            publicKey: Data(CryptoTestVectors.ed25519Pk)
        ))
        var tampered = CryptoTestVectors.ed25519Sig
        tampered[0] ^= 0xFF
        #expect(!provider.ed25519IsValidSignature(
            Data(tampered),
            for: message,
            publicKey: Data(CryptoTestVectors.ed25519Pk)
        ))
    }

    @Test
    func curve25519() throws {
        // RFC 7748, Section 6.1: Alice's public key derives from her private key.
        let alicePrivateKey = Data(CryptoTestVectors.rfc7748AliceSkey)
        #expect(
            Array(provider.curve25519PublicKey(for: alicePrivateKey))
                == CryptoTestVectors.rfc7748AlicePkey
        )

        let sharedSecret = try provider.curve25519SharedSecret(
            privateKey: Data(CryptoTestVectors.rfc7748Skey1),
            peerPublicKey: Data(CryptoTestVectors.rfc7748Pkey1)
        )
        #expect(Array(sharedSecret) == CryptoTestVectors.rfc7748Csec1)
    }

    @Test
    func x25519KeyAgreementIsSymmetric() throws {
        let alice = provider.makeCurve25519PrivateKey()
        let bob = provider.makeCurve25519PrivateKey()
        let aliceShared = try provider.curve25519SharedSecret(
            privateKey: alice,
            peerPublicKey: provider.curve25519PublicKey(for: bob)
        )
        let bobShared = try provider.curve25519SharedSecret(
            privateKey: bob,
            peerPublicKey: provider.curve25519PublicKey(for: alice)
        )
        #expect(aliceShared == bobShared)
    }
}
