/// Encoding of HAP BLE advertisement payloads.
///
/// - SeeAlso: HAP Specification R2, Section 7.4.2 HAP BLE Advertisement Formats
public enum BLEAdvertisementEncoding {

    /// The Flags AD structure: LE General Discoverable Mode, BR/EDR Not Supported.
    ///
    /// - SeeAlso: HAP Specification R2, Section 7.4.2.1.1 Flags
    public static let flags: [UInt8] = [0x02, 0x01, 0x06]

    /// Apple's Bluetooth company identifier (`0x004C`), little-endian.
    static let companyIdentifier: [UInt8] = [0x4C, 0x00]

    /// Builds the SubType and Length byte: the 3 most significant bits are the HomeKit
    /// advertising format subtype (1), the remaining 5 bits the length of the remaining
    /// manufacturer data bytes.
    static func subtypeAndLength(_ length: UInt8) -> UInt8 {
        precondition(length < 32)
        return 0b0010_0000 | length
    }
}

// MARK: - Regular Advertisement

public extension BLERegularManufacturerData {

    /// The complete advertising data: the Flags AD structure followed by the
    /// Manufacturer Data AD structure (26 bytes total).
    ///
    /// - SeeAlso: HAP Specification R2, Section 7.4.2.1 HAP BLE Regular Advertisement Format
    var advertisingData: Data {
        var bytes = BLEAdvertisementEncoding.flags
        bytes.append(0x16)  // LEN: 22 bytes follow
        bytes.append(0xFF)  // ADT: manufacturer specific data
        bytes.append(contentsOf: BLEAdvertisementEncoding.companyIdentifier)
        bytes.append(Self.type)  // TY: HAP BLE regular advertisement
        bytes.append(BLEAdvertisementEncoding.subtypeAndLength(17))  // STL
        bytes.append(statusFlags.rawValue)  // SF
        bytes.append(contentsOf: [
            deviceID.0, deviceID.1, deviceID.2, deviceID.3, deviceID.4, deviceID.5
        ])
        // ACID: 16-bit little-endian accessory category identifier.
        bytes.append(contentsOf: littleEndianBytes(UInt16(accessoryCategory.rawValue)))
        bytes.append(contentsOf: littleEndianBytes(globalStateNumber))
        bytes.append(configurationNumber)
        bytes.append(Self.compatibleVersion)
        if let setupHash {
            bytes.append(contentsOf: [setupHash.0, setupHash.1, setupHash.2, setupHash.3])
        } else {
            bytes.append(contentsOf: [0, 0, 0, 0])
        }
        return Data(bytes)
    }
}

// MARK: - Encrypted Notification Advertisement

public extension BLEEncryptedNotificationManufacturerData {

    /// Encrypts a broadcasted event into an encrypted notification advertisement.
    ///
    /// The 12-byte payload `GSN (2, little-endian) ‖ IID (2, little-endian) ‖ value (8)`
    /// is encrypted with ChaCha20-Poly1305 using the broadcast encryption key, the global
    /// state number as the 64-bit nonce, and the advertising identifier as additional
    /// authenticated data. The authentication tag is truncated to 4 bytes.
    ///
    /// - Parameters:
    ///   - globalStateNumber: The global state number, incremented for this event.
    ///   - characteristicIID: The instance ID of the characteristic whose value changed.
    ///   - value: The characteristic value, at most 8 bytes (zero-padded).
    ///   - advertisingID: The 6-byte advertising identifier.
    ///   - broadcastKey: The 32-byte broadcast encryption key.
    ///   - crypto: The cryptographic provider.
    ///
    /// - Returns: The complete advertising data (31 bytes total).
    ///
    /// - SeeAlso: HAP Specification R2, Section 7.4.2.2
    static func encryptedAdvertisingData<Crypto: CryptoProvider>(
        globalStateNumber: UInt16,
        characteristicIID: UInt16,
        value: Data,
        advertisingID: Data,
        broadcastKey: Data,
        using crypto: Crypto
    ) throws(HAPError) -> Data {
        guard value.count <= 8, advertisingID.count == 6 else {
            throw .invalidData
        }
        var plaintext = littleEndianBytes(globalStateNumber)
        plaintext.append(contentsOf: littleEndianBytes(characteristicIID))
        plaintext.append(contentsOf: value)
        plaintext.append(contentsOf: [UInt8](repeating: 0, count: 8 - value.count))
        // The nonce is the global state number as a 64-bit little-endian value.
        let sealed = try crypto.seal(
            Data(plaintext),
            key: broadcastKey,
            nonce: Data(littleEndianBytes(UInt64(globalStateNumber))),
            authenticatedData: advertisingID
        )
        let sealedBytes = Array(sealed)

        var bytes = BLEAdvertisementEncoding.flags
        bytes.append(0x1B)  // LEN: 27 bytes follow
        bytes.append(0xFF)  // ADT: manufacturer specific data
        bytes.append(contentsOf: BLEAdvertisementEncoding.companyIdentifier)
        bytes.append(Self.type)  // TY: HAP BLE encrypted notification advertisement
        bytes.append(BLEAdvertisementEncoding.subtypeAndLength(22))  // STL
        bytes.append(contentsOf: advertisingID)
        bytes.append(contentsOf: sealedBytes[0 ..< 12])   // encrypted GSN ‖ IID ‖ value
        bytes.append(contentsOf: sealedBytes[12 ..< 16])  // first 4 bytes of the auth tag
        return Data(bytes)
    }
}
