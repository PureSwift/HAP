/// The encrypted channel of a verified HAP session.
///
/// After Pair Verify, all traffic is encrypted with ChaCha20-Poly1305 using per-direction
/// keys and 64-bit little-endian nonce counters, starting at 0 and incrementing per message:
/// - HAP over IP encrypts frames of up to 1024 bytes, authenticating the 2-byte length
///   prefix (§6.5.2 Session Security).
/// - HAP over BLE encrypts each HAP PDU without additional authenticated data
///   (§7.4.7.5 Securing HAP PDUs).
///
/// Decryption failures are unrecoverable: the session must be torn down and the controller
/// must establish a new session via Pair Verify.
public struct SecureSession<Crypto: CryptoProvider> {

    /// Maximum plaintext length of a HAP over IP frame.
    public static var maximumFrameLength: Int { 1024 }

    private let crypto: Crypto
    private let encryptKey: Data
    private let decryptKey: Data
    private var encryptNonce: UInt64 = 0
    private var decryptNonce: UInt64 = 0

    /// Creates a secure session channel.
    ///
    /// - Parameters:
    ///   - crypto: The cryptographic provider.
    ///   - encryptKey: Key for accessory-to-controller messages (`AccessoryToControllerKey`).
    ///   - decryptKey: Key for controller-to-accessory messages (`ControllerToAccessoryKey`).
    public init(crypto: Crypto, encryptKey: Data, decryptKey: Data) {
        self.crypto = crypto
        self.encryptKey = encryptKey
        self.decryptKey = decryptKey
    }

    /// Creates the secure session for a completed Pair Verify, deriving the
    /// `Control-Salt` channel keys.
    public init(crypto: Crypto, pairVerify result: PairVerifyResult) {
        let keys = result.controlChannelKeys(using: crypto)
        self.init(
            crypto: crypto,
            encryptKey: keys.accessoryToController,
            decryptKey: keys.controllerToAccessory
        )
    }

    // MARK: Messages

    /// Encrypts an accessory-to-controller message and advances the nonce counter.
    ///
    /// Returns the ciphertext with the 16-byte authentication tag appended.
    public mutating func encrypt(_ message: Data) throws(HAPError) -> Data {
        try encrypt(message, authenticatedData: Data())
    }

    /// Encrypts an accessory-to-controller message with additional authenticated data
    /// and advances the nonce counter.
    public mutating func encrypt(
        _ message: Data,
        authenticatedData: Data
    ) throws(HAPError) -> Data {
        let sealed = try crypto.seal(
            message,
            key: encryptKey,
            nonce: Self.nonce(encryptNonce),
            authenticatedData: authenticatedData
        )
        encryptNonce &+= 1
        return sealed
    }

    /// Decrypts a controller-to-accessory message and advances the nonce counter.
    ///
    /// - Throws: ``HAPError/notAuthorized`` if authentication fails; the session must
    ///   then be torn down.
    public mutating func decrypt(_ message: Data) throws(HAPError) -> Data {
        try decrypt(message, authenticatedData: Data())
    }

    /// Decrypts a controller-to-accessory message with additional authenticated data
    /// and advances the nonce counter.
    public mutating func decrypt(
        _ message: Data,
        authenticatedData: Data
    ) throws(HAPError) -> Data {
        let opened = try crypto.open(
            message,
            key: decryptKey,
            nonce: Self.nonce(decryptNonce),
            authenticatedData: authenticatedData
        )
        decryptNonce &+= 1
        return opened
    }

    // MARK: HAP over IP Frames

    /// Encrypts a message into HAP over IP frames (§6.5.2).
    ///
    /// Each frame is `length (2 bytes, little-endian) ‖ ciphertext ‖ tag (16 bytes)`, where
    /// the length describes the plaintext and is authenticated as additional data. Messages
    /// larger than ``maximumFrameLength`` are split across multiple frames.
    public mutating func encryptFrames(_ message: Data) throws(HAPError) -> Data {
        let bytes = Array(message)
        var output = [UInt8]()
        var offset = 0
        repeat {
            let end = min(offset + Self.maximumFrameLength, bytes.count)
            let length = end - offset
            let lengthPrefix: [UInt8] = [
                UInt8(truncatingIfNeeded: length),
                UInt8(truncatingIfNeeded: length >> 8)
            ]
            let sealed = try encrypt(
                Data(bytes[offset ..< end]),
                authenticatedData: Data(lengthPrefix)
            )
            output.append(contentsOf: lengthPrefix)
            output.append(contentsOf: sealed)
            offset = end
        } while offset < bytes.count
        return Data(output)
    }

    /// Decrypts a single HAP over IP frame, including its 2-byte length prefix.
    public mutating func decryptFrame(_ frame: Data) throws(HAPError) -> Data {
        let bytes = Array(frame)
        guard bytes.count >= 2 + 16 else { throw .invalidData }
        let length = Int(bytes[0]) | Int(bytes[1]) << 8
        guard length <= Self.maximumFrameLength,
              bytes.count == 2 + length + 16
        else { throw .invalidData }
        return try decrypt(
            Data(bytes[2...]),
            authenticatedData: Data(bytes[0 ..< 2])
        )
    }
}

private extension SecureSession {

    /// The 64-bit little-endian nonce for a counter value.
    static func nonce(_ counter: UInt64) -> Data {
        Data([
            UInt8(truncatingIfNeeded: counter),
            UInt8(truncatingIfNeeded: counter >> 8),
            UInt8(truncatingIfNeeded: counter >> 16),
            UInt8(truncatingIfNeeded: counter >> 24),
            UInt8(truncatingIfNeeded: counter >> 32),
            UInt8(truncatingIfNeeded: counter >> 40),
            UInt8(truncatingIfNeeded: counter >> 48),
            UInt8(truncatingIfNeeded: counter >> 56)
        ])
    }
}
