import Testing
import FoundationEmbedded
import HAP
@testable import HAPCryptoKit

/// Tests against the RFC test vectors used by the ADK's crypto test suite
/// (RFC 8032, RFC 7748, RFC 7539, HKDF-SHA-512).
@Suite
struct SwiftCryptoProviderTests {

    let provider = SwiftCryptoProvider()

    @Test
    func sha512() {
        let digest = provider.sha512(FoundationEmbedded.Data(Array("abc".utf8)))
        #expect(Array(digest) == CryptoTestVectors.sha512Hash)
    }

    @Test
    func hkdfSHA512() {
        let key = provider.hkdfSHA512(
            inputKeyMaterial: FoundationEmbedded.Data(CryptoTestVectors.hkdfIKM),
            salt: FoundationEmbedded.Data(CryptoTestVectors.hkdfSalt),
            info: FoundationEmbedded.Data(CryptoTestVectors.hkdfInfo),
            outputByteCount: CryptoTestVectors.hkdfOKM.count
        )
        #expect(Array(key) == CryptoTestVectors.hkdfOKM)
    }

    @Test
    func chaCha20Poly1305() throws {
        let sealed = try provider.seal(
            FoundationEmbedded.Data(Array(CryptoTestVectors.chacha20Poly1305Pt.utf8)),
            key: FoundationEmbedded.Data(CryptoTestVectors.chacha20Poly1305Key),
            nonce: FoundationEmbedded.Data(CryptoTestVectors.chacha20Poly1305Nonce),
            authenticatedData: FoundationEmbedded.Data(CryptoTestVectors.chacha20Poly1305Aad)
        )
        let expected = CryptoTestVectors.chacha20Poly1305Ct + CryptoTestVectors.chacha20Poly1305Tag
        #expect(Array(sealed) == expected)

        let opened = try provider.open(
            sealed,
            key: FoundationEmbedded.Data(CryptoTestVectors.chacha20Poly1305Key),
            nonce: FoundationEmbedded.Data(CryptoTestVectors.chacha20Poly1305Nonce),
            authenticatedData: FoundationEmbedded.Data(CryptoTestVectors.chacha20Poly1305Aad)
        )
        #expect(Array(opened) == Array(CryptoTestVectors.chacha20Poly1305Pt.utf8))
    }

    @Test
    func chaCha20Poly1305RejectsTamperedCiphertext() throws {
        let key = FoundationEmbedded.Data(CryptoTestVectors.chacha20Poly1305Key)
        let nonce = FoundationEmbedded.Data(CryptoTestVectors.chacha20Poly1305Nonce)
        var sealed = Array(try provider.seal(
            FoundationEmbedded.Data(Array(CryptoTestVectors.chacha20Poly1305Pt.utf8)),
            key: key,
            nonce: nonce,
            authenticatedData: FoundationEmbedded.Data()
        ))
        sealed[0] ^= 0xFF
        #expect(throws: HAPError.notAuthorized) {
            try provider.open(
                FoundationEmbedded.Data(sealed),
                key: key,
                nonce: nonce,
                authenticatedData: FoundationEmbedded.Data()
            )
        }
    }

    @Test
    func chaCha20Poly1305PadsEightByteNonce() throws {
        // HAP 64-bit nonces are zero-padded to 96 bits.
        let message = FoundationEmbedded.Data(Array("hello".utf8))
        let key = FoundationEmbedded.Data([UInt8](repeating: 0x11, count: 32))
        let sealedShort = try provider.seal(
            message,
            key: key,
            nonce: FoundationEmbedded.Data([1, 2, 3, 4, 5, 6, 7, 8]),
            authenticatedData: FoundationEmbedded.Data()
        )
        let sealedFull = try provider.seal(
            message,
            key: key,
            nonce: FoundationEmbedded.Data([0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8]),
            authenticatedData: FoundationEmbedded.Data()
        )
        #expect(sealedShort == sealedFull)
    }

    @Test
    func ed25519() throws {
        let privateKey = FoundationEmbedded.Data(CryptoTestVectors.ed25519Sk)
        #expect(Array(provider.ed25519PublicKey(for: privateKey)) == CryptoTestVectors.ed25519Pk)

        let message = FoundationEmbedded.Data(CryptoTestVectors.ed25519M)
        // CryptoKit produces randomized Ed25519 signatures, so the deterministic RFC 8032
        // signature vector cannot be compared byte-for-byte — but both must verify.
        let signature = try provider.ed25519Signature(for: message, privateKey: privateKey)
        #expect(provider.ed25519IsValidSignature(
            FoundationEmbedded.Data(CryptoTestVectors.ed25519Sig),
            for: message,
            publicKey: FoundationEmbedded.Data(CryptoTestVectors.ed25519Pk)
        ))
        #expect(provider.ed25519IsValidSignature(
            signature,
            for: message,
            publicKey: FoundationEmbedded.Data(CryptoTestVectors.ed25519Pk)
        ))
        var tampered = CryptoTestVectors.ed25519Sig
        tampered[0] ^= 0xFF
        #expect(!provider.ed25519IsValidSignature(
            FoundationEmbedded.Data(tampered),
            for: message,
            publicKey: FoundationEmbedded.Data(CryptoTestVectors.ed25519Pk)
        ))
    }

    @Test
    func curve25519() throws {
        // RFC 7748, Section 6.1: Alice's public key derives from her private key.
        let alicePrivateKey = FoundationEmbedded.Data(CryptoTestVectors.rfc7748AliceSkey)
        #expect(
            Array(provider.curve25519PublicKey(for: alicePrivateKey))
                == CryptoTestVectors.rfc7748AlicePkey
        )

        let sharedSecret = try provider.curve25519SharedSecret(
            privateKey: FoundationEmbedded.Data(CryptoTestVectors.rfc7748Skey1),
            peerPublicKey: FoundationEmbedded.Data(CryptoTestVectors.rfc7748Pkey1)
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
