import Testing
@testable import HAP

@Suite
struct BLEGATTDatabaseTests {

    @Test
    func instanceIDTypes() {
        #expect(
            BLEGATTDatabase.serviceInstanceIDCharacteristicType.rawValue.uuidString
                == "E604E95D-A759-4817-87D3-AA005083A0D1"
        )
        #expect(
            BLEGATTDatabase.characteristicInstanceIDDescriptorType.rawValue.uuidString
                == "DC46F0FE-81D2-4616-B5D9-6ABDD796939A"
        )
        // Neither is an Apple-defined short-form type.
        #expect(!BLEGATTDatabase.serviceInstanceIDCharacteristicType.isAppleDefined)
        #expect(!BLEGATTDatabase.characteristicInstanceIDDescriptorType.isAppleDefined)
    }

    @Test
    func databaseLayout() throws {
        let accessory = Accessory(
            aid: 1,
            category: .lighting,
            name: "Light",
            manufacturer: "Acme",
            model: "L1",
            serialNumber: "0001",
            firmwareVersion: "1.0.0",
            services: [
                Service(
                    iid: 1,
                    serviceType: .accessoryInformation,
                    debugDescription: "accessory-information",
                    properties: [],
                    characteristics: [
                        .bool(BoolCharacteristic(
                            iid: 2,
                            characteristicType: .identify,
                            debugDescription: "identify",
                            properties: [.writable]
                        ))
                    ]
                ),
                Service(
                    iid: 8,
                    serviceType: .lightBulb,
                    debugDescription: "light-bulb",
                    properties: [.primaryService],
                    characteristics: [
                        .bool(BoolCharacteristic(
                            iid: 9,
                            characteristicType: .on,
                            debugDescription: "on",
                            properties: [.readable, .writable, .supportsEventNotification]
                        ))
                    ]
                )
            ]
        )
        let services = BLEGATTDatabase.services(for: accessory)
        #expect(services.count == 2)

        let information = try #require(services.first)
        #expect(information.type == .accessoryInformation)
        #expect(information.instanceID == 1)
        #expect(Array(information.instanceIDValue) == [0x01, 0x00])
        #expect(information.characteristics.count == 1)
        let identify = try #require(information.characteristics.first)
        #expect(identify.type == .identify)
        #expect(identify.instanceID == 2)
        #expect(!identify.supportsIndication)  // no event notifications

        let lightBulb = services[1]
        #expect(lightBulb.instanceID == 8)
        let on = try #require(lightBulb.characteristics.first)
        #expect(on.instanceID == 9)
        #expect(Array(on.instanceIDValue) == [0x09, 0x00])
        #expect(on.supportsIndication)

        // GATT UUIDs are the HAP types serialized little-endian.
        #expect(Array(lightBulb.bluetoothUUID) == [
            0x91, 0x52, 0x76, 0xBB, 0x26, 0x00, 0x00, 0x80,
            0x00, 0x10, 0x00, 0x00, 0x43, 0x00, 0x00, 0x00
        ])
    }
}
