
/// A HomeKit setup hash: the first 4 bytes of `SHA-512(setup ID ‖ device ID)`.
///
/// The setup hash is included in the transport-specific advertisement data (the BLE regular
/// advertisement and the IP Bonjour TXT record) so controllers can match a scanned setup
/// payload to a discovered accessory. The device ID is converted to uppercase for the
/// computation.
///
/// - SeeAlso: HAP Specification R13, Section 4.2.3.1 Setup Hash Generation
public struct SetupHash: RawRepresentable, Equatable, Hashable, Sendable {

    /// The 4 hash bytes, packed big-endian (first digest byte in the most significant position).
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

public extension SetupHash {

    /// Creates a setup hash from the first 4 bytes of a SHA-512 digest.
    init?(digest: Data) {
        guard digest.count >= 4 else { return nil }
        self.init(rawValue: UInt32(digest[0]) << 24
                          | UInt32(digest[1]) << 16
                          | UInt32(digest[2]) << 8
                          | UInt32(digest[3]))
    }

    /// Computes the setup hash for a setup ID and device ID.
    ///
    /// - Parameters:
    ///   - setupID: The accessory's setup ID.
    ///   - deviceID: The accessory's device ID string, e.g. `"E1:91:1A:70:85:AA"`.
    ///     Converted to uppercase for the computation.
    ///   - crypto: The cryptographic provider used to compute the SHA-512 digest.
    init<Crypto: CryptoProvider>(setupID: SetupID, deviceID: String, using crypto: Crypto) {
        let message = Data(Array((setupID.rawValue + deviceID.uppercased()).utf8))
        self.init(digest: crypto.sha512(message))!
    }

    /// The 4 hash bytes in transmission order.
    var data: Data {
        Data([
            UInt8(truncatingIfNeeded: rawValue >> 24),
            UInt8(truncatingIfNeeded: rawValue >> 16),
            UInt8(truncatingIfNeeded: rawValue >> 8),
            UInt8(truncatingIfNeeded: rawValue)
        ])
    }
}
