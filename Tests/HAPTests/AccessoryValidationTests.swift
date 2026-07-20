import Testing
@testable import HAP

@Suite
struct AccessoryValidationTests {

    func makeAccessory(services: [Service]) -> Accessory {
        Accessory(
            aid: 1,
            category: .lighting,
            name: "Light Bulb",
            manufacturer: "Acme",
            model: "LB1",
            serialNumber: "0001",
            firmwareVersion: "1.0.0",
            services: services
        )
    }

    func makeAccessoryInformation(iid: UInt64 = 1) -> Service {
        Service(
            iid: iid,
            serviceType: .accessoryInformation,
            debugDescription: "accessory-information",
            properties: []
        )
    }

    func makeLightBulb(iid: UInt64 = 2, characteristicIID: UInt64 = 3) -> Service {
        Service(
            iid: iid,
            serviceType: .lightBulb,
            debugDescription: "light-bulb",
            properties: [.primaryService],
            characteristics: [
                .bool(BoolCharacteristic(
                    iid: characteristicIID,
                    characteristicType: .on,
                    debugDescription: "on",
                    properties: [.readable, .writable]
                ))
            ]
        )
    }

    @Test
    func valid() throws {
        let accessory = makeAccessory(services: [makeAccessoryInformation(), makeLightBulb()])
        try accessory.validate()
    }

    @Test
    func missingServices() {
        let accessory = makeAccessory(services: [])
        #expect(throws: AccessoryValidationError.missingServices) {
            try accessory.validate()
        }
    }

    @Test
    func missingAccessoryInformation() {
        let accessory = makeAccessory(services: [makeLightBulb()])
        #expect(throws: AccessoryValidationError.missingAccessoryInformationService) {
            try accessory.validate()
        }
    }

    @Test
    func accessoryInformationInstanceID() {
        let accessory = makeAccessory(services: [makeAccessoryInformation(iid: 5), makeLightBulb()])
        #expect(throws: AccessoryValidationError.invalidAccessoryInformationServiceInstanceID(5)) {
            try accessory.validate()
        }
    }

    @Test
    func duplicateInstanceID() {
        let accessory = makeAccessory(
            services: [makeAccessoryInformation(), makeLightBulb(iid: 2, characteristicIID: 2)]
        )
        #expect(throws: AccessoryValidationError.duplicateInstanceID(2)) {
            try accessory.validate()
        }
    }

    @Test
    func zeroInstanceID() {
        let accessory = makeAccessory(
            services: [makeAccessoryInformation(), makeLightBulb(iid: 2, characteristicIID: 0)]
        )
        #expect(throws: AccessoryValidationError.zeroInstanceID) {
            try accessory.validate()
        }
    }

    @Test
    func bluetoothInstanceIDLimit() throws {
        let accessory = makeAccessory(
            services: [makeAccessoryInformation(), makeLightBulb(iid: 2, characteristicIID: 0x10000)]
        )
        // Bluetooth LE limits instance IDs to UInt16.max; IP does not.
        #expect(throws: AccessoryValidationError.instanceIDExceedsBluetoothLimit(0x10000)) {
            try accessory.validate()
        }
        #expect(throws: AccessoryValidationError.instanceIDExceedsBluetoothLimit(0x10000)) {
            try accessory.validate(transport: .ble)
        }
        try accessory.validate(transport: .ip)
    }

    @Test
    func linkedServices() throws {
        var lightBulb = makeLightBulb()
        lightBulb.linkedServices = [2]  // links to itself
        let selfLinked = makeAccessory(services: [makeAccessoryInformation(), lightBulb])
        #expect(throws: AccessoryValidationError.invalidLinkedService(2)) {
            try selfLinked.validate()
        }
        lightBulb.linkedServices = [4]  // links to a nonexistent service
        let danglingLink = makeAccessory(services: [makeAccessoryInformation(), lightBulb])
        #expect(throws: AccessoryValidationError.invalidLinkedService(4)) {
            try danglingLink.validate()
        }
        lightBulb.linkedServices = [1]  // links to the Accessory Information service
        let validLink = makeAccessory(services: [makeAccessoryInformation(), lightBulb])
        try validLink.validate()
    }
}
