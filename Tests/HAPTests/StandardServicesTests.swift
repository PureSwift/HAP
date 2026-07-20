import Testing
@testable import HAP

@Suite
struct StandardServicesTests {

    func makeAccessory(hardwareVersion: String? = nil) -> Accessory {
        var accessory = Accessory(
            aid: 1,
            category: .lighting,
            name: "Light",
            manufacturer: "Acme",
            model: "L1",
            serialNumber: "0001",
            firmwareVersion: "1.0.0"
        )
        accessory.hardwareVersion = hardwareVersion
        accessory.services = [
            .accessoryInformation(for: accessory),
            .hapProtocolInformation,
            .pairing
        ]
        return accessory
    }

    @Test
    func accessoryInformation() throws {
        let service = Service.accessoryInformation(for: makeAccessory())
        #expect(service.iid == 1)
        #expect(service.serviceType == .accessoryInformation)
        // identify, manufacturer, model, name, serial number, firmware revision.
        #expect(service.characteristics?.count == 6)
        let identify = try #require(service.characteristics?.first)
        #expect(identify.iid == 2)
        #expect(identify.characteristicType == .identify)
        #expect(identify.properties == [.writable])
        #expect(service.characteristics?.map(\.iid) == [2, 3, 4, 5, 6, 7])
    }

    @Test
    func hardwareRevisionIsOptional() {
        let with = Service.accessoryInformation(for: makeAccessory(hardwareVersion: "1.0"))
        #expect(with.characteristics?.count == 7)
        #expect(with.characteristics?.last?.characteristicType == .hardwareRevision)
        #expect(with.characteristics?.last?.iid == 8)
    }

    @Test
    func protocolInformation() throws {
        let service = Service.hapProtocolInformation
        #expect(service.iid == 0x10)
        #expect(service.properties == [.bleSupportsConfiguration])
        let signature = try #require(service.characteristics?.first)
        #expect(signature.characteristicType == .serviceSignature)
        #expect(signature.iid == 0x11)
        let version = try #require(service.characteristics?.last)
        #expect(version.characteristicType == .version)
        #expect(version.iid == 0x12)
    }

    @Test
    func pairingService() throws {
        let service = Service.pairing
        #expect(service.iid == 0x20)
        #expect(service.serviceType == .pairing)
        let characteristics = try #require(service.characteristics)
        #expect(characteristics.map(\.iid) == [0x22, 0x23, 0x24, 0x25])
        #expect(characteristics.map(\.characteristicType) == [
            .pairSetup, .pairVerify, .pairingFeatures, .pairingPairings
        ])
        // Pair Setup and Pair Verify are open-access: the pairing exchanges themselves
        // run without a secure session.
        for index in 0 ... 1 {
            #expect(characteristics[index].properties.contains(.bleReadableWithoutSecurity))
            #expect(characteristics[index].properties.contains(.bleWritableWithoutSecurity))
        }
        // Pairing management requires a secure session.
        #expect(!characteristics[3].properties.contains(.bleReadableWithoutSecurity))
        #expect(characteristics[3].properties.contains(.readable))
        #expect(characteristics[3].properties.contains(.writable))
    }

    /// The standard services compose into a valid Bluetooth LE attribute database.
    @Test
    func standardServicesValidate() throws {
        var accessory = makeAccessory(hardwareVersion: "1.0")
        // Add an application service in the conventional range.
        accessory.services?.append(Service(
            iid: 0x30,
            serviceType: .lightBulb,
            debugDescription: "light-bulb",
            properties: [.primaryService],
            characteristics: [
                .bool(BoolCharacteristic(
                    iid: 0x33,
                    characteristicType: .on,
                    debugDescription: "on",
                    properties: [.readable, .writable, .supportsEventNotification]
                ))
            ]
        ))
        try accessory.validate(transport: .ble)
    }
}
