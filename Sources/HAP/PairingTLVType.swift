import TLVCoding

/// TLV item types used in pairing payloads.
///
/// - SeeAlso: HAP Specification R2, Table 5-6 TLV Values
public enum PairingTLVType: UInt8, Equatable, Hashable, Sendable, CaseIterable {

    /// Method to use for pairing (integer). See ``PairingMethod``.
    case method = 0x00

    /// Identifier for authentication (UTF-8).
    case identifier = 0x01

    /// 16+ bytes of random salt (bytes).
    case salt = 0x02

    /// Curve25519, SRP public key, or signed Ed25519 key (bytes).
    case publicKey = 0x03

    /// Ed25519 or SRP proof (bytes).
    case proof = 0x04

    /// Encrypted data with auth tag at end (bytes).
    case encryptedData = 0x05

    /// State of the pairing process (integer). 1=M1, 2=M2, etc.
    case state = 0x06

    /// Error code (integer). Must only be present if error code is not 0. See ``PairingError``.
    case error = 0x07

    /// Seconds to delay until retrying a setup code (integer).
    case retryDelay = 0x08

    /// X.509 certificate (bytes).
    case certificate = 0x09

    /// Ed25519 signature (bytes).
    case signature = 0x0A

    /// Permissions of the controller being added (integer). See ``PairingPermissions``.
    case permissions = 0x0B

    /// Non-last fragment of data (bytes). If length is 0, it's an ACK.
    case fragmentData = 0x0C

    /// Last fragment of data (bytes).
    case fragmentLast = 0x0D

    /// Pairing type flags (32-bit unsigned integer). See ``PairingFlags``.
    case flags = 0x13

    /// Zero-length TLV that separates different TLVs in a list.
    case separator = 0xFF
}

public extension PairingTLVType {

    /// The TLV type code for use with `TLVCoding`.
    var typeCode: TLVTypeCode {
        TLVTypeCode(rawValue: rawValue)
    }
}
