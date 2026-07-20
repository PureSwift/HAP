import Testing
@testable import HAP

@Suite
struct AccessoryLookupTests {

    var accessory: Accessory {
        Accessory(
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
                            properties: [.readable, .writable]
                        ))
                    ]
                )
            ]
        )
    }

    @Test
    func serviceLookup() {
        #expect(accessory.service(iid: 8)?.serviceType == .lightBulb)
        #expect(accessory.service(iid: 1)?.serviceType == .accessoryInformation)
        #expect(accessory.service(iid: 9) == nil)  // characteristic iid, not a service
        #expect(accessory.service(iid: 99) == nil)
    }

    @Test
    func characteristicLookup() throws {
        let match = try #require(accessory.characteristic(iid: 9))
        #expect(match.characteristic.characteristicType == .on)
        #expect(match.service.iid == 8)
        #expect(accessory.characteristic(iid: 8) == nil)  // service iid, not a characteristic
        #expect(accessory.characteristic(iid: 99) == nil)
    }

    @Test
    func typedLookup() throws {
        let identify = try #require(accessory.characteristic(.identify, in: .accessoryInformation))
        #expect(identify.characteristic.iid == 2)
        #expect(accessory.characteristic(.on, in: .accessoryInformation) == nil)
        #expect(accessory.characteristic(.on, in: .lightBulb)?.characteristic.iid == 9)
    }
}
