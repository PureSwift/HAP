
/// Cryptographic primitives required by the HomeKit Accessory Protocol.
///
/// Mirrors the ADK's PAL crypto interface (`HAPCrypto.h`). Hosted platforms can back this
/// protocol with swift-crypto; embedded targets can plug in hardware acceleration or an
/// SDK crypto library.
public protocol CryptoProvider {

    /// The SRP server session type produced by ``makeSRPServer(username:salt:verifier:)``.
    associatedtype SRP: SRPServer

    // MARK: SHA-512

    /// Computes the SHA-512 digest (64 bytes) of a message.
    func sha512(_ message: Data) -> Data

    // MARK: HKDF-SHA-512

    /// Derives a key using HKDF with SHA-512.
    func hkdfSHA512(inputKeyMaterial: Data, salt: Data, info: Data, outputByteCount: Int) -> Data

    // MARK: ChaCha20-Poly1305

    /// Encrypts and authenticates a message with ChaCha20-Poly1305.
    ///
    /// Returns the ciphertext with the 16-byte authentication tag appended.
    ///
    /// - Note: HAP uses 64-bit nonces, zero-padded in the least significant bytes to the
    ///   96-bit nonce required by RFC 8439.
    ///
    /// - SeeAlso: HAP Specification R2, Section 5.9 AEAD Algorithm
    func seal(
        _ message: Data,
        key: Data,
        nonce: Data,
        authenticatedData: Data
    ) throws(HAPError) -> Data

    /// Decrypts and verifies a ChaCha20-Poly1305 ciphertext with the 16-byte authentication
    /// tag appended.
    ///
    /// - Throws: ``HAPError/notAuthorized`` if the authentication tag is invalid.
    func open(
        _ ciphertext: Data,
        key: Data,
        nonce: Data,
        authenticatedData: Data
    ) throws(HAPError) -> Data

    // MARK: Ed25519

    /// Generates a new Ed25519 private key (32 bytes).
    func makeEd25519PrivateKey() -> Data

    /// Derives the Ed25519 public key (32 bytes) for a private key.
    func ed25519PublicKey(for privateKey: Data) -> Data

    /// Signs a message with an Ed25519 private key, returning the 64-byte signature.
    func ed25519Signature(for message: Data, privateKey: Data) throws(HAPError) -> Data

    /// Verifies an Ed25519 signature.
    func ed25519IsValidSignature(_ signature: Data, for message: Data, publicKey: Data) -> Bool

    // MARK: X25519

    /// Generates a new Curve25519 private key (32 bytes).
    func makeCurve25519PrivateKey() -> Data

    /// Derives the Curve25519 public key (32 bytes) for a private key.
    func curve25519PublicKey(for privateKey: Data) -> Data

    /// Computes the X25519 Diffie-Hellman shared secret (32 bytes).
    func curve25519SharedSecret(
        privateKey: Data,
        peerPublicKey: Data
    ) throws(HAPError) -> Data

    // MARK: SRP-6a

    /// Computes an SRP verifier for a username and password.
    ///
    /// Uses the 3072-bit group from RFC 5054 with SHA-512, per the HAP SRP modifications.
    /// During Pair Setup the username is `"Pair-Setup"` and the password is the formatted
    /// setup code (`XXX-XX-XXX`).
    ///
    /// - SeeAlso: HAP Specification R2, Section 5.5 Secure Remote Password
    func srpVerifier(username: String, password: String, salt: Data) -> Data

    /// Creates a server-side SRP session for a stored verifier.
    func makeSRPServer(
        username: String,
        salt: Data,
        verifier: Data
    ) throws(HAPError) -> SRP
}
