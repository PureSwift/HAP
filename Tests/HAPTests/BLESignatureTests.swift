import Testing
@testable import HAP

@Suite
struct BLESignatureTests {

    /// The HAP base UUID suffix, little-endian (as serialized in HAP-BLE PDUs).
    let baseUUIDSuffixLE: [UInt8] = [
        0x91, 0x52, 0x76, 0xBB, 0x26, 0x00, 0x00, 0x80, 0x00, 0x10, 0x00, 0x00
    ]

    func bleUUID(_ shortValue: UInt8) -> [UInt8] {
        baseUUIDSuffixLE + [shortValue, 0x00, 0x00, 0x00]
    }

    var lightBulbService: Service {
        Service(
            iid: 2,
            serviceType: .lightBulb,
            debugDescription: "light-bulb",
            properties: [.primaryService]
        )
    }

    @Test
    func uuidSerializesLittleEndian() {
        #expect(Array(HAPUUID.lightBulb.bleData) == bleUUID(0x43))
        #expect(Array(HAPUUID.on.bleData) == bleUUID(0x25))
    }

    @Test
    func characteristicSignature() {
        // A brightness-style UInt8 characteristic: percentage 0...100.
        let characteristic = Characteristic.uint8(UInt8Characteristic(
            iid: 3,
            characteristicType: .brightness,
            debugDescription: "brightness",
            properties: [.readable, .writable, .supportsEventNotification],
            units: .percentage,
            minimumValue: 0,
            maximumValue: 100,
            stepValue: 1
        ))
        let body = Array(characteristic.bleSignatureReadResponseBody(service: lightBulbService))
        let expected: [UInt8] =
            [0x04, 0x10] + bleUUID(0x08)            // characteristic type (Brightness)
            + [0x07, 0x02, 0x02, 0x00]              // service instance ID = 2
            + [0x06, 0x10] + bleUUID(0x43)          // service type (Light Bulb)
            + [0x0A, 0x02, 0xB0, 0x00]              // properties: read|write|events secure
            + [0x0C, 0x07, 0x04, 0x00, 0xAD, 0x27, 0x01, 0x00, 0x00]  // uint8, percentage
            + [0x0D, 0x02, 0x00, 0x64]              // valid range 0...100
        #expect(body == expected)                   // step 1 is omitted
    }

    @Test
    func floatMetadata() {
        // A current-temperature-style Float characteristic: celsius 0...100 step 0.1.
        let characteristic = Characteristic.float(FloatCharacteristic(
            iid: 5,
            characteristicType: .currentTemperature,
            debugDescription: "current-temperature",
            properties: [.readable, .supportsEventNotification],
            units: .celsius,
            minimumValue: 0,
            maximumValue: 100,
            stepValue: 0.1
        ))
        let service = Service(
            iid: 4,
            serviceType: .temperatureSensor,
            debugDescription: "temperature-sensor",
            properties: []
        )
        let body = Array(characteristic.bleSignatureReadResponseBody(service: service))
        let expected: [UInt8] =
            [0x04, 0x10] + bleUUID(0x11)
            + [0x07, 0x02, 0x04, 0x00]
            + [0x06, 0x10] + bleUUID(0x8A)
            + [0x0A, 0x02, 0x90, 0x00]              // read | events
            + [0x0C, 0x07, 0x14, 0x00, 0x2F, 0x27, 0x01, 0x00, 0x00]  // float, celsius
            + [0x0D, 0x08,
               0x00, 0x00, 0x00, 0x00,              // 0.0
               0x00, 0x00, 0xC8, 0x42]              // 100.0
            + [0x0E, 0x04, 0xCD, 0xCC, 0xCC, 0x3D]  // step 0.1
        #expect(body == expected)
    }

    @Test
    func boolCharacteristicOmitsNumericMetadata() {
        let characteristic = Characteristic.bool(BoolCharacteristic(
            iid: 3,
            characteristicType: .on,
            debugDescription: "on",
            properties: [.readable, .writable, .supportsEventNotification]
        ))
        let body = Array(characteristic.bleSignatureReadResponseBody(service: lightBulbService))
        let expected: [UInt8] =
            [0x04, 0x10] + bleUUID(0x25)
            + [0x07, 0x02, 0x02, 0x00]
            + [0x06, 0x10] + bleUUID(0x43)
            + [0x0A, 0x02, 0xB0, 0x00]
            + [0x0C, 0x07, 0x01, 0x00, 0x00, 0x27, 0x01, 0x00, 0x00]  // bool, unitless
        #expect(body == expected)
    }

    @Test
    func validValuesAndUserDescription() {
        var uint8 = UInt8Characteristic(
            iid: 6,
            characteristicType: .securitySystemTargetState,
            debugDescription: "target-state",
            properties: [.readable, .writable],
            units: .none,
            minimumValue: 0,
            maximumValue: 3,
            stepValue: 1
        )
        uint8.manufacturerDescription = "Mode"
        uint8.validValues = [0, 1, 3]
        uint8.validValuesRanges = [0 ... 1]
        let characteristic = Characteristic.uint8(uint8)
        let service = Service(
            iid: 2,
            serviceType: .securitySystem,
            debugDescription: "security-system",
            properties: []
        )
        let body = Array(characteristic.bleSignatureReadResponseBody(service: service))
        let expected: [UInt8] =
            [0x04, 0x10] + bleUUID(0x67)            // Security System Target State
            + [0x07, 0x02, 0x02, 0x00]
            + [0x06, 0x10] + bleUUID(0x7E)
            + [0x0A, 0x02, 0x30, 0x00]              // read | write
            + [0x0B, 0x04] + Array("Mode".utf8)     // user description
            + [0x0C, 0x07, 0x04, 0x00, 0x00, 0x27, 0x01, 0x00, 0x00]
            + [0x0D, 0x02, 0x00, 0x03]              // range 0...3
            + [0x11, 0x03, 0x00, 0x01, 0x03]        // valid values
            + [0x12, 0x02, 0x00, 0x01]              // valid values ranges
        #expect(body == expected)
    }

    @Test
    func blePropertiesMask() {
        let characteristic = Characteristic.uint8(UInt8Characteristic(
            iid: 1,
            characteristicType: .brightness,
            debugDescription: "test",
            properties: [
                .bleReadableWithoutSecurity, .bleWritableWithoutSecurity,
                .supportsAuthorizationData, .requiresTimedWrite,
                .readable, .writable, .hidden, .supportsEventNotification,
                .bleSupportsDisconnectedNotification, .bleSupportsBroadcastNotification
            ],
            units: .none,
            minimumValue: 0,
            maximumValue: 255,
            stepValue: 1
        ))
        #expect(characteristic.blePropertiesDescriptor == 0x03FF)
    }

    // MARK: Service Signatures

    @Test
    func serviceSignature() {
        var service = lightBulbService
        service.linkedServices = [8, 0x0109]
        let body = Array(service.bleSignatureReadResponseBody)
        let expected: [UInt8] = [
            0x0F, 0x02, 0x01, 0x00,              // properties: primary
            0x10, 0x04, 0x08, 0x00, 0x09, 0x01   // linked services 8, 265
        ]
        #expect(body == expected)
    }

    @Test
    func emptyServiceSignature() {
        let body = Array(Service.bleEmptySignatureReadResponseBody)
        #expect(body == [0x0F, 0x02, 0x00, 0x00, 0x10, 0x00])
    }

    @Test
    func hiddenServiceProperties() {
        let service = Service(
            iid: 10,
            serviceType: .accessoryInformation,
            debugDescription: "test",
            properties: [.hidden, .bleSupportsConfiguration]
        )
        #expect(service.blePropertiesDescriptor == 0x0006)
        #expect(Array(service.bleSignatureReadResponseBody) == [
            0x0F, 0x02, 0x06, 0x00,
            0x10, 0x00
        ])
    }
}
