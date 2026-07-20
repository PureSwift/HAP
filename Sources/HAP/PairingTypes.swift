/// The device ID of an accessory server (6 bytes, e.g. a MAC address).
///
/// - Note: ABI-compatible with the C `HAPAccessoryServerDeviceID` struct (`sizeof == 6`).
public struct AccessoryServerDeviceID {
    public var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    public init(bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
        self.bytes = bytes
    }
}

// MARK: -

/// The Ed25519 long-term secret key of an accessory server (32 bytes).
///
/// - Note: ABI-compatible with the C `HAPAccessoryServerLongTermSecretKey` struct (`sizeof == 32`).
public struct AccessoryServerLongTermSecretKey {
    public var bytes: (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )
}

// MARK: -

/// The pairing identifier of a paired controller (up to 36 bytes).
public struct ControllerPairingIdentifier {
    /// Raw identifier bytes. Maximum 36 bytes.
    public var bytes: [UInt8]

    public init(bytes: [UInt8]) {
        precondition(bytes.count <= 36, "ControllerPairingIdentifier must not exceed 36 bytes")
        self.bytes = bytes
    }
}

// MARK: -

/// The Ed25519 long-term public key of a paired controller (32 bytes).
///
/// - Note: ABI-compatible with the C `HAPControllerPublicKey` struct (`sizeof == 32`).
public struct ControllerPublicKey {
    public var bytes: (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )
}
