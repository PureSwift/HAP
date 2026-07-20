import Testing
@testable import HAP

@Suite
struct SetupPayloadTests {

    /// Example from HAP Specification R13, Section 4.3: outlet with WAC and IP support.
    @Test
    func encodeWACAndIP() throws {
        let payload = SetupPayload(
            category: try #require(AccessoryCategory(rawValue: 7)),
            supportsWAC: true,
            supportsIP: true,
            setupCode: try #require(SetupCode(rawValue: "518-08-582")),
            setupID: try #require(SetupID(rawValue: "7OSX"))
        )
        #expect(payload.uri == "X-HM://007JNU5AE7OSX")
    }

    /// Example from HAP Specification R13, Section 4.3: same accessory, BLE only.
    @Test
    func encodeBLE() throws {
        let payload = SetupPayload(
            category: try #require(AccessoryCategory(rawValue: 7)),
            supportsBLE: true,
            setupCode: try #require(SetupCode(rawValue: "518-08-582")),
            setupID: try #require(SetupID(rawValue: "7OSX"))
        )
        #expect(payload.uri == "X-HM://0076CDMX27OSX")
    }

    @Test
    func decode() throws {
        let payload = try #require(SetupPayload(uri: "X-HM://007JNU5AE7OSX"))
        #expect(payload.category.rawValue == 7)
        #expect(payload.supportsWAC)
        #expect(payload.supportsIP)
        #expect(!payload.supportsBLE)
        #expect(!payload.isPaired)
        #expect(payload.setupCode.rawValue == "518-08-582")
        #expect(payload.setupID.rawValue == "7OSX")
    }

    @Test
    func roundtrip() throws {
        let uris = ["X-HM://007JNU5AE7OSX", "X-HM://0076CDMX27OSX"]
        for uri in uris {
            let payload = try #require(SetupPayload(uri: uri))
            #expect(payload.uri == uri)
        }
    }

    @Test
    func decodeRejectsInvalid() {
        #expect(SetupPayload(uri: "X-HM://007JNU5AE7OS") == nil)   // too short
        #expect(SetupPayload(uri: "X-HM://007jnu5ae7OSX") == nil)  // lowercase
        #expect(SetupPayload(uri: "X-YM://007JNU5AE7OSX") == nil)  // wrong scheme
    }

    @Test
    func setupCodeValidation() {
        #expect(SetupCode(rawValue: "518-08-582") != nil)
        #expect(SetupCode(rawValue: "51808582") == nil)
        #expect(SetupCode(rawValue: "518-08-58X") == nil)
        #expect(SetupCode(digits: "51808582")?.rawValue == "518-08-582")
        #expect(SetupCode(value: 51_808_582)?.rawValue == "518-08-582")
        #expect(SetupCode(value: 5)?.rawValue == "000-00-005")
        #expect(SetupCode(value: 100_000_000) == nil)
        #expect(SetupCode(rawValue: "518-08-582")?.isSecure == true)
        #expect(SetupCode(rawValue: "123-45-678")?.isSecure == false)
        #expect(SetupCode(rawValue: "000-00-000")?.isSecure == false)
    }

    /// Setup hash test vectors from HAP Specification R13, Section 4.2.3.1.
    @Test
    func setupHash() throws {
        let setupID = try #require(SetupID(rawValue: "7OSX"))
        var crypto = MockCryptoProvider()
        crypto.sha512Digests[Data(Array("7OSXE1:91:1A:70:85:AA".utf8))] = try #require(Data(hexString:
            "C9FE1BCFB89B86E218AB56C5F1986EE9B9CC954A06C3769AC6433D472793EA71" +
            "89DE46F2A0E043363D5E1E4401D066F17AAC6D9C9A993F439879A331CF55F6CB"
        ))
        crypto.sha512Digests[Data(Array("7OSXC8:D8:58:C6:63:F5".utf8))] = try #require(Data(hexString:
            "EF5D8E9BD0635D10CBF528F1DC968D7E7A9380BD7AA216A0AFFD264D36FCF632" +
            "CA58B4F8618D738E81FE01B3F7D03BBAB03C59553EC378720312FF66B49A58A3"
        ))

        let hash1 = SetupHash(setupID: setupID, deviceID: "E1:91:1A:70:85:AA", using: crypto)
        #expect(hash1.rawValue == 0xC9FE1BCF)
        #expect(Array(hash1.data) == [0xC9, 0xFE, 0x1B, 0xCF])

        // The device ID is uppercased before hashing.
        let hash2 = SetupHash(setupID: setupID, deviceID: "c8:d8:58:c6:63:f5", using: crypto)
        #expect(hash2.rawValue == 0xEF5D8E9B)
    }
}
