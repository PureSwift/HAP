import Testing
import TLVCoding
@testable import HAP

/// Example accessory definitions, driven end-to-end through the BLE procedure server.
///
/// These mirror the ADK's Lightbulb and Lock sample applications and serve as usage
/// examples for defining accessories with this library.
@Suite
struct ExampleAccessoryTests {

    var now: HAPTime { HAPTime(rawValue: 5000) }

    // MARK: Light Bulb

    /// A light bulb: On (0x33) and Brightness (0x34) on a Light Bulb service.
    func makeLightBulb() -> Accessory {
        var accessory = Accessory(
            aid: 1,
            category: .lighting,
            name: "Desk Lamp",
            manufacturer: "Acme",
            model: "Lamp1,1",
            serialNumber: "099DB48E9E28",
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
                    )),
                    .uint8(UInt8Characteristic(
                        iid: 0x34,
                        characteristicType: .brightness,
                        debugDescription: "brightness",
                        properties: [.readable, .writable, .supportsEventNotification],
                        units: .percentage,
                        minimumValue: 0,
                        maximumValue: 100,
                        stepValue: 1
                    ))
                ]
            )
        ]
        return accessory
    }

    /// A lock: Lock Current State (0x33) and Lock Target State (0x34), which requires
    /// timed writes, on a Lock Mechanism service.
    func makeLock() -> Accessory {
        var accessory = Accessory(
            aid: 1,
            category: .locks,
            name: "Front Door",
            manufacturer: "Acme",
            model: "Lock1,1",
            serialNumber: "099DB48E9E29",
            firmwareVersion: "1.0.0"
        )
        accessory.services = [
            .accessoryInformation(for: accessory),
            .hapProtocolInformation,
            .pairing,
            Service(
                iid: 0x30,
                serviceType: .lockMechanism,
                debugDescription: "lock-mechanism",
                properties: [.primaryService],
                characteristics: [
                    .uint8(UInt8Characteristic(
                        iid: 0x33,
                        characteristicType: .lockCurrentState,
                        debugDescription: "lock-current-state",
                        properties: [.readable, .supportsEventNotification],
                        units: .none,
                        minimumValue: 0,
                        maximumValue: 3,  // unsecured, secured, jammed, unknown
                        stepValue: 1
                    )),
                    .uint8(UInt8Characteristic(
                        iid: 0x34,
                        characteristicType: .lockTargetState,
                        debugDescription: "lock-target-state",
                        properties: [
                            .readable, .writable, .supportsEventNotification,
                            .requiresTimedWrite
                        ],
                        units: .none,
                        minimumValue: 0,
                        maximumValue: 1,  // unsecured, secured
                        stepValue: 1
                    ))
                ]
            )
        ]
        return accessory
    }

    func makeServer(
        accessory: Accessory,
        values: [UInt64: CharacteristicValue]
    ) -> BLEProcedureServer<StandardDataSource<MockCharacteristicDataSource>, MockBLEConfigurationContext> {
        var application = MockCharacteristicDataSource()
        application.values = values
        return BLEProcedureServer(
            accessory: accessory,
            dataSource: StandardDataSource(application: application),
            configuration: MockBLEConfigurationContext()
        )
    }

    func read(
        _ server: inout BLEProcedureServer<StandardDataSource<MockCharacteristicDataSource>, MockBLEConfigurationContext>,
        iid: UInt16
    ) -> CharacteristicValue? {
        let response = server.handle(
            BLEPDURequest(opcode: .characteristicRead, transactionID: 1, instanceID: iid),
            isSecured: true,
            now: now
        )
        guard response.status == .success,
              let body = response.body,
              let container = TLVContainer(data: .init(body)),
              let value = container[BLEPDUParamType.value.typeCode],
              let match = server.accessory.characteristic(iid: UInt64(iid))
        else { return nil }
        return CharacteristicValue(bleData: Data(value), format: match.characteristic.format)
    }

    func writeBody(_ value: CharacteristicValue, ttl: UInt8? = nil) -> Data {
        var container = TLVContainer()
        if let ttl {
            container.items.append(TLVItem(type: BLEPDUParamType.ttl.typeCode, value: .init([ttl])))
        }
        container.items.append(TLVItem(
            type: BLEPDUParamType.value.typeCode,
            value: .init(value.bleData)
        ))
        return Data(container.data)
    }

    // MARK: Tests

    @Test
    func lightBulbExample() throws {
        let accessory = makeLightBulb()
        try accessory.validate(transport: .ble)
        var server = makeServer(accessory: accessory, values: [0x33: .bool(false), 0x34: .uint8(50)])

        // Standard characteristics are served automatically.
        #expect(read(&server, iid: 4) == .string("Lamp1,1"))          // model
        #expect(read(&server, iid: 0x12) == .string("2.2.0"))         // protocol version

        // Turn the lamp on at 75%.
        let onWrite = server.handle(
            BLEPDURequest(
                opcode: .characteristicWrite,
                transactionID: 2,
                instanceID: 0x33,
                body: writeBody(.bool(true))
            ),
            isSecured: true,
            now: now
        )
        #expect(onWrite.status == .success)
        _ = server.handle(
            BLEPDURequest(
                opcode: .characteristicWrite,
                transactionID: 3,
                instanceID: 0x34,
                body: writeBody(.uint8(75))
            ),
            isSecured: true,
            now: now
        )
        #expect(read(&server, iid: 0x33) == .bool(true))
        #expect(read(&server, iid: 0x34) == .uint8(75))
    }

    @Test
    func lockExample() throws {
        let accessory = makeLock()
        try accessory.validate(transport: .ble)
        var server = makeServer(accessory: accessory, values: [0x33: .uint8(1), 0x34: .uint8(1)])

        #expect(read(&server, iid: 0x33) == .uint8(1))  // secured

        // Lock Target State requires a timed write: a plain write is rejected.
        let plainWrite = server.handle(
            BLEPDURequest(
                opcode: .characteristicWrite,
                transactionID: 2,
                instanceID: 0x34,
                body: writeBody(.uint8(0))
            ),
            isSecured: true,
            now: now
        )
        #expect(plainWrite.status == .invalidRequest)

        // Unlock via timed write + execute.
        let staged = server.handle(
            BLEPDURequest(
                opcode: .characteristicTimedWrite,
                transactionID: 3,
                instanceID: 0x34,
                body: writeBody(.uint8(0), ttl: 25)  // 2.5 seconds
            ),
            isSecured: true,
            now: now
        )
        #expect(staged.status == .success)
        let executed = server.handle(
            BLEPDURequest(opcode: .characteristicExecuteWrite, transactionID: 4, instanceID: 0x34),
            isSecured: true,
            now: now.advanced(byMilliseconds: 500)
        )
        #expect(executed.status == .success)
        #expect(read(&server, iid: 0x34) == .uint8(0))  // unsecured
    }
}
