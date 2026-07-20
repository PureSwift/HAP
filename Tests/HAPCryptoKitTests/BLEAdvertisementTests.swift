import Testing
@testable import HAP
@testable import HAPCryptoKit

@Suite
struct BLEAdvertisementTests {

    let deviceID: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (
        0xE1, 0x91, 0x1A, 0x70, 0x85, 0xAA
    )

    @Test
    func regularAdvertisement() throws {
        let manufacturerData = BLERegularManufacturerData(
            statusFlags: .notPaired,
            deviceID: deviceID,
            accessoryCategory: try #require(AccessoryCategory(rawValue: 5)),  // lighting
            globalStateNumber: 0x0203,
            configurationNumber: 1,
            setupHash: (0xC9, 0xFE, 0x1B, 0xCF)
        )
        let data = Array(manufacturerData.advertisingData)
        #expect(data.count == 26)
        #expect(data == [
            0x02, 0x01, 0x06,              // flags: LE General Discoverable, no BR/EDR
            0x16, 0xFF,                    // manufacturer data, 22 bytes
            0x4C, 0x00,                    // Apple
            0x06,                          // TY: regular advertisement
            0x31,                          // STL: subtype 1, length 17
            0x01,                          // SF: not paired
            0xE1, 0x91, 0x1A, 0x70, 0x85, 0xAA,  // device ID
            0x05, 0x00,                    // ACID: lighting
            0x03, 0x02,                    // GSN, little-endian
            0x01,                          // CN
            0x02,                          // CV
            0xC9, 0xFE, 0x1B, 0xCF        // setup hash
        ])
    }

    @Test
    func regularAdvertisementPairedWithoutSetupHash() throws {
        let manufacturerData = BLERegularManufacturerData(
            statusFlags: [],
            deviceID: deviceID,
            accessoryCategory: try #require(AccessoryCategory(rawValue: 5)),
            globalStateNumber: 1,
            configurationNumber: 1,
            setupHash: nil
        )
        let data = Array(manufacturerData.advertisingData)
        #expect(data.count == 26)
        #expect(data[9] == 0x00)  // SF: paired
        #expect(Array(data.suffix(4)) == [0, 0, 0, 0])
    }

    @Test
    func encryptedNotificationAdvertisement() throws {
        let provider = SwiftCryptoProvider()
        let advertisingID = Data([0xE1, 0x91, 0x1A, 0x70, 0x85, 0xAA])
        let broadcastKey = Data([UInt8](repeating: 0x42, count: 32))
        let gsn: UInt16 = 0x1234

        let data = Array(try BLEEncryptedNotificationManufacturerData.encryptedAdvertisingData(
            globalStateNumber: gsn,
            characteristicIID: 9,
            value: Data([0x01]),  // e.g. On = true
            advertisingID: advertisingID,
            broadcastKey: broadcastKey,
            using: provider
        ))
        #expect(data.count == 31)
        #expect(Array(data[0 ..< 3]) == [0x02, 0x01, 0x06])
        #expect(data[3] == 0x1B)   // manufacturer data length
        #expect(data[4] == 0xFF)
        #expect(Array(data[5 ..< 7]) == [0x4C, 0x00])
        #expect(data[7] == 0x11)   // TY: encrypted notification
        #expect(data[8] == 0x36)   // STL: subtype 1, length 22
        #expect(Array(data[9 ..< 15]) == Array(advertisingID))

        // A controller with the broadcast key can decrypt the payload: the ciphertext is
        // GSN ‖ IID ‖ value with the GSN as nonce and the advertising ID as AAD. Verify
        // by re-encrypting the expected plaintext and comparing.
        var expectedPlaintext: [UInt8] = [0x34, 0x12, 0x09, 0x00, 0x01]
        expectedPlaintext.append(contentsOf: [UInt8](repeating: 0, count: 7))
        let expectedSealed = Array(try provider.seal(
            Data(expectedPlaintext),
            key: broadcastKey,
            nonce: Data([0x34, 0x12, 0, 0, 0, 0, 0, 0]),
            authenticatedData: advertisingID
        ))
        #expect(Array(data[15 ..< 27]) == Array(expectedSealed[0 ..< 12]))
        #expect(Array(data[27 ..< 31]) == Array(expectedSealed[12 ..< 16]))
    }

    @Test
    func encryptedNotificationRejectsInvalidInput() {
        let provider = SwiftCryptoProvider()
        // Value longer than 8 bytes.
        #expect(throws: HAPError.invalidData) {
            try BLEEncryptedNotificationManufacturerData.encryptedAdvertisingData(
                globalStateNumber: 1,
                characteristicIID: 1,
                value: Data([UInt8](repeating: 0, count: 9)),
                advertisingID: Data([1, 2, 3, 4, 5, 6]),
                broadcastKey: Data([UInt8](repeating: 0, count: 32)),
                using: provider
            )
        }
        // Advertising identifier must be 6 bytes.
        #expect(throws: HAPError.invalidData) {
            try BLEEncryptedNotificationManufacturerData.encryptedAdvertisingData(
                globalStateNumber: 1,
                characteristicIID: 1,
                value: Data([0x01]),
                advertisingID: Data([1, 2, 3]),
                broadcastKey: Data([UInt8](repeating: 0, count: 32)),
                using: provider
            )
        }
    }
}
