import Testing
@testable import HAP

@Suite
struct CharacteristicValueTests {

    // MARK: BLE Wire Format

    @Test
    func bleEncoding() {
        #expect(Array(CharacteristicValue.bool(true).bleData) == [0x01])
        #expect(Array(CharacteristicValue.bool(false).bleData) == [0x00])
        #expect(Array(CharacteristicValue.uint8(0x2A).bleData) == [0x2A])
        #expect(Array(CharacteristicValue.uint16(0x1234).bleData) == [0x34, 0x12])
        #expect(Array(CharacteristicValue.uint32(0xDEAD_BEEF).bleData) == [0xEF, 0xBE, 0xAD, 0xDE])
        #expect(Array(CharacteristicValue.uint64(1).bleData) == [1, 0, 0, 0, 0, 0, 0, 0])
        #expect(Array(CharacteristicValue.int(-1).bleData) == [0xFF, 0xFF, 0xFF, 0xFF])
        #expect(Array(CharacteristicValue.float(100).bleData) == [0x00, 0x00, 0xC8, 0x42])
        #expect(Array(CharacteristicValue.string("hi").bleData) == [0x68, 0x69])
        #expect(Array(CharacteristicValue.tlv8(Data([0x01, 0x00])).bleData) == [0x01, 0x00])
    }

    @Test
    func bleRoundtrip() throws {
        let values: [CharacteristicValue] = [
            .data(Data([1, 2, 3])),
            .bool(true),
            .uint8(200),
            .uint16(65_000),
            .uint32(4_000_000_000),
            .uint64(.max),
            .int(-123_456),
            .float(0.1),
            .string("héllo wörld"),
            .tlv8(Data([0x02, 0x01, 0xFF]))
        ]
        for value in values {
            let decoded = try #require(
                CharacteristicValue(bleData: value.bleData, format: value.format)
            )
            #expect(decoded == value)
        }
    }

    @Test
    func bleDecodeRejectsMalformed() {
        #expect(CharacteristicValue(bleData: Data([0x02]), format: .bool) == nil)
        #expect(CharacteristicValue(bleData: Data(), format: .bool) == nil)
        #expect(CharacteristicValue(bleData: Data([1, 2]), format: .uint8) == nil)
        #expect(CharacteristicValue(bleData: Data([1]), format: .uint16) == nil)
        #expect(CharacteristicValue(bleData: Data([1, 2, 3]), format: .uint32) == nil)
        #expect(CharacteristicValue(bleData: Data([1, 2, 3, 4, 5]), format: .float) == nil)
        // Zero-length data and TLV8 values are allowed.
        #expect(CharacteristicValue(bleData: Data(), format: .data) == .data(Data()))
    }

    // MARK: Validation

    func makeUInt8(
        minimum: UInt8 = 0,
        maximum: UInt8 = 100,
        step: UInt8 = 1,
        validValues: [UInt8]? = nil,
        validValuesRanges: [ClosedRange<UInt8>]? = nil
    ) -> Characteristic {
        var characteristic = UInt8Characteristic(
            iid: 1,
            characteristicType: .brightness,
            debugDescription: "test",
            properties: [.readable, .writable],
            units: .percentage,
            minimumValue: minimum,
            maximumValue: maximum,
            stepValue: step
        )
        characteristic.validValues = validValues
        characteristic.validValuesRanges = validValuesRanges
        return .uint8(characteristic)
    }

    @Test
    func validatesRange() {
        let characteristic = makeUInt8(minimum: 10, maximum: 90)
        #expect(characteristic.isValidValue(.uint8(10)))
        #expect(characteristic.isValidValue(.uint8(50)))
        #expect(characteristic.isValidValue(.uint8(90)))
        #expect(!characteristic.isValidValue(.uint8(9)))
        #expect(!characteristic.isValidValue(.uint8(91)))
    }

    @Test
    func validatesStep() {
        let characteristic = makeUInt8(minimum: 10, maximum: 50, step: 10)
        #expect(characteristic.isValidValue(.uint8(10)))
        #expect(characteristic.isValidValue(.uint8(30)))
        #expect(!characteristic.isValidValue(.uint8(35)))
    }

    @Test
    func validatesValidValues() {
        let characteristic = makeUInt8(maximum: 255, validValues: [0, 1, 4])
        #expect(characteristic.isValidValue(.uint8(0)))
        #expect(characteristic.isValidValue(.uint8(4)))
        #expect(!characteristic.isValidValue(.uint8(2)))

        let ranged = makeUInt8(maximum: 255, validValuesRanges: [3 ... 5])
        #expect(ranged.isValidValue(.uint8(4)))
        #expect(!ranged.isValidValue(.uint8(6)))

        let both = makeUInt8(maximum: 255, validValues: [0], validValuesRanges: [3 ... 5])
        #expect(both.isValidValue(.uint8(0)))
        #expect(both.isValidValue(.uint8(3)))
        #expect(!both.isValidValue(.uint8(1)))
    }

    @Test
    func validatesFormatMismatch() {
        let characteristic = makeUInt8()
        #expect(!characteristic.isValidValue(.uint16(5)))
        #expect(!characteristic.isValidValue(.bool(true)))
    }

    @Test
    func validatesInt() {
        let characteristic = Characteristic.int(IntCharacteristic(
            iid: 1,
            characteristicType: .brightness,
            debugDescription: "test",
            properties: [.readable, .writable],
            units: .percentage,
            minimumValue: -90,
            maximumValue: 90,
            stepValue: 45
        ))
        #expect(characteristic.isValidValue(.int(-90)))
        #expect(characteristic.isValidValue(.int(0)))
        #expect(characteristic.isValidValue(.int(45)))
        #expect(!characteristic.isValidValue(.int(50)))
        #expect(!characteristic.isValidValue(.int(-91)))
    }

    @Test
    func validatesFloat() {
        let characteristic = Characteristic.float(FloatCharacteristic(
            iid: 1,
            characteristicType: .currentTemperature,
            debugDescription: "test",
            properties: [.readable],
            units: .celsius,
            minimumValue: -50,
            maximumValue: 100,
            stepValue: 0.1
        ))
        #expect(characteristic.isValidValue(.float(21.5)))
        #expect(!characteristic.isValidValue(.float(101)))
        #expect(!characteristic.isValidValue(.float(.infinity)))
        #expect(!characteristic.isValidValue(.float(.nan)))
    }

    @Test
    func validatesStringLength() {
        let characteristic = Characteristic.string(StringCharacteristic(
            iid: 1,
            characteristicType: .name,
            debugDescription: "test",
            properties: [.readable],
            maxLength: 8
        ))
        #expect(characteristic.isValidValue(.string("12345678")))
        #expect(!characteristic.isValidValue(.string("123456789")))
        // Length limits are in UTF-8 bytes, not characters.
        #expect(!characteristic.isValidValue(.string("ééééé")))  // 10 bytes
    }
}
