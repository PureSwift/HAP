import Testing
import BluetoothGATT
@testable import HAP

@Suite
struct BLEGATTAttributesTests {

    var accessory: Accessory {
        var accessory = Accessory(
            aid: 1,
            category: .lighting,
            name: "Light",
            manufacturer: "Acme",
            model: "L1",
            serialNumber: "0001",
            firmwareVersion: "1.0.0"
        )
        accessory.services = [
            .accessoryInformation(for: accessory),
            .hapProtocolInformation,
            .pairing,
            Service(
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
            )
        ]
        return accessory
    }

    @Test
    func uuidConversionMatchesFoundation() {
        // The HAP UUID conversion agrees with Bluetooth's canonical Foundation converter.
        let lightBulb = HAPUUID.lightBulb
        #expect(
            BLEGATTDatabase.bluetoothUUID(lightBulb)
                == BluetoothUUID(uuid: lightBulb.rawValue)
        )
        #expect(
            BLEGATTDatabase.bluetoothUUID(.on).description.uppercased()
                == "00000025-0000-1000-8000-0026BB765291"
        )
    }

    @Test
    func serviceLayout() throws {
        let services = BLEGATTDatabase.gattServices(for: accessory, as: [UInt8].self)
        // Accessory Information, HAP Protocol Information, Pairing, Light Bulb.
        #expect(services.count == 4)

        let lightBulb = try #require(services.last)
        #expect(lightBulb.isPrimary)
        #expect(lightBulb.uuid == BluetoothUUID(uuid: HAPUUID.lightBulb.rawValue))
        // Service Instance ID characteristic first, then the HAP characteristics.
        #expect(lightBulb.characteristics.count == 2)

        let serviceInstanceID = lightBulb.characteristics[0]
        #expect(serviceInstanceID.uuid == BLEGATTDatabase.bluetoothUUID(
            BLEGATTDatabase.serviceInstanceIDCharacteristicType
        ))
        #expect(serviceInstanceID.properties == [.read])
        #expect(serviceInstanceID.value == [0x30, 0x00])  // instance ID, little-endian

        let on = lightBulb.characteristics[1]
        #expect(on.uuid == BluetoothUUID(uuid: HAPUUID.on.rawValue))
        // Read + write, plus indicate because the characteristic supports events.
        #expect(on.properties.contains(.read))
        #expect(on.properties.contains(.write))
        #expect(on.properties.contains(.indicate))
        #expect(on.permissions == [.read, .write])

        // The Characteristic Instance ID descriptor carries the 2-byte instance ID.
        #expect(on.descriptors.count == 1)
        #expect(on.descriptors[0].uuid == BLEGATTDatabase.bluetoothUUID(
            BLEGATTDatabase.characteristicInstanceIDDescriptorType
        ))
        #expect(on.descriptors[0].value == [0x33, 0x00])
        #expect(on.descriptors[0].permissions == [.read])
    }

    @Test
    func characteristicWithoutEventsHasNoIndicate() throws {
        let services = BLEGATTDatabase.gattServices(for: accessory, as: [UInt8].self)
        // The Identify characteristic (in Accessory Information) has no event notifications.
        let information = try #require(services.first)
        let identify = try #require(information.characteristics.first { characteristic in
            characteristic.uuid == BluetoothUUID(uuid: HAPUUID.identify.rawValue)
        })
        #expect(!identify.properties.contains(.indicate))
        #expect(identify.properties.contains(.write))
    }
}

extension Array: @retroactive DataContainer where Element == UInt8 {}
