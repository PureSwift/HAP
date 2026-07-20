import Testing
import TLVCoding
@testable import HAP

@Suite
struct BLEProcedureServerTests {

    // Instance IDs: 1 accessory information, 2 identify,
    // 8 light bulb, 9 on, 10 brightness, 11 open-access, 12 timed-write-only.
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
                    linkedServices: [1],
                    characteristics: [
                        .bool(BoolCharacteristic(
                            iid: 9,
                            characteristicType: .on,
                            debugDescription: "on",
                            properties: [.readable, .writable, .supportsEventNotification]
                        )),
                        .uint8(UInt8Characteristic(
                            iid: 10,
                            characteristicType: .brightness,
                            debugDescription: "brightness",
                            properties: [.readable, .writable],
                            units: .percentage,
                            minimumValue: 0,
                            maximumValue: 100,
                            stepValue: 1
                        )),
                        .bool(BoolCharacteristic(
                            iid: 11,
                            characteristicType: .on,
                            debugDescription: "open-access",
                            properties: [
                                .readable, .writable,
                                .bleReadableWithoutSecurity, .bleWritableWithoutSecurity
                            ]
                        )),
                        .uint8(UInt8Characteristic(
                            iid: 12,
                            characteristicType: .lockTargetState,
                            debugDescription: "timed-only",
                            properties: [.readable, .writable, .requiresTimedWrite],
                            units: .none,
                            minimumValue: 0,
                            maximumValue: 1,
                            stepValue: 1
                        ))
                    ]
                )
            ]
        )
    }

    func makeServer(
        values: [UInt64: CharacteristicValue] = [9: .bool(true), 10: .uint8(42), 11: .bool(false), 12: .uint8(0)]
    ) -> BLEProcedureServer<MockCharacteristicDataSource, MockBLEConfigurationContext> {
        var dataSource = MockCharacteristicDataSource()
        dataSource.values = values
        return BLEProcedureServer(
            accessory: accessory,
            dataSource: dataSource,
            configuration: MockBLEConfigurationContext()
        )
    }

    var now: HAPTime { HAPTime(rawValue: 1_000_000) }

    func request(
        _ opcode: BLEPDUOpcode,
        iid: UInt16,
        body: Data? = nil,
        tid: UInt8 = 0x42
    ) -> BLEPDURequest {
        BLEPDURequest(opcode: opcode, transactionID: tid, instanceID: iid, body: body)
    }

    /// Builds a request body from parameter TLVs.
    func body(_ parameters: [(BLEPDUParamType, Data)]) -> Data {
        var container = TLVContainer()
        for (type, value) in parameters {
            container.items.append(TLVItem(type: type.typeCode, value: .init(value)))
        }
        return Data(container.data)
    }

    /// Extracts the HAP-Param-Value from a response body.
    func value(from response: BLEPDUResponse) -> Data? {
        guard let body = response.body,
              let container = TLVContainer(data: .init(body))
        else { return nil }
        return container.items
            .first { $0.type == BLEPDUParamType.value.typeCode }
            .map { Data($0.value) }
    }

    // MARK: Signature Reads

    @Test
    func signatureReadWorksWithoutSecureSession() {
        var server = makeServer()
        let response = server.handle(
            request(.characteristicSignatureRead, iid: 9),
            isSecured: false,
            now: now
        )
        #expect(response.status == .success)
        #expect(response.transactionID == 0x42)
        // The body is the characteristic signature, verified byte-exactly in BLESignatureTests.
        #expect(response.body != nil)
    }

    @Test
    func signatureReadUnknownInstanceID() {
        var server = makeServer()
        let response = server.handle(
            request(.characteristicSignatureRead, iid: 99),
            isSecured: true,
            now: now
        )
        #expect(response.status == .invalidInstanceID)
    }

    @Test
    func serviceSignatureRead() {
        var server = makeServer()
        let response = server.handle(request(.serviceSignatureRead, iid: 8), isSecured: true, now: now)
        #expect(response.status == .success)
        #expect(Array(response.body ?? Data()) == [
            0x0F, 0x02, 0x01, 0x00,        // primary service
            0x10, 0x02, 0x01, 0x00         // linked service 1
        ])
    }

    /// An invalid service instance ID must still yield a valid response (§7.3.4.13).
    @Test
    func serviceSignatureReadInvalidInstanceID() {
        var server = makeServer()
        let response = server.handle(request(.serviceSignatureRead, iid: 99), isSecured: true, now: now)
        #expect(response.status == .success)
        #expect(Array(response.body ?? Data()) == [0x0F, 0x02, 0x00, 0x00, 0x10, 0x00])
    }

    // MARK: Reads

    @Test
    func read() {
        var server = makeServer()
        let response = server.handle(request(.characteristicRead, iid: 10), isSecured: true, now: now)
        #expect(response.status == .success)
        #expect(Array(value(from: response) ?? Data()) == [42])
    }

    @Test
    func readRequiresSecureSession() {
        var server = makeServer()
        let response = server.handle(request(.characteristicRead, iid: 10), isSecured: false, now: now)
        #expect(response.status == .insufficientAuthentication)

        // A characteristic marked readable without security is accessible.
        let open = server.handle(request(.characteristicRead, iid: 11), isSecured: false, now: now)
        #expect(open.status == .success)
    }

    @Test
    func readNonReadableCharacteristic() {
        var server = makeServer()
        let response = server.handle(request(.characteristicRead, iid: 2), isSecured: true, now: now)
        #expect(response.status == .invalidRequest)  // identify is write-only
    }

    @Test
    func readPropagatesHandlerErrors() {
        var server = makeServer()
        server.dataSource.readFailure = .notAuthorized
        #expect(
            server.handle(request(.characteristicRead, iid: 10), isSecured: true, now: now).status
                == .insufficientAuthorization
        )
        server.dataSource.readFailure = .outOfResources
        #expect(
            server.handle(request(.characteristicRead, iid: 10), isSecured: true, now: now).status
                == .maxProcedures
        )
        server.dataSource.readFailure = .busy
        #expect(
            server.handle(request(.characteristicRead, iid: 10), isSecured: true, now: now).status
                == .invalidRequest
        )
    }

    // MARK: Writes

    @Test
    func write() {
        var server = makeServer()
        let response = server.handle(
            request(.characteristicWrite, iid: 10, body: body([(.value, Data([75]))])),
            isSecured: true,
            now: now
        )
        #expect(response.status == .success)
        #expect(server.dataSource.values[10] == .uint8(75))
        #expect(server.dataSource.writes.count == 1)
        #expect(server.dataSource.writes[0].context.transportType == .ble)
    }

    @Test
    func writeRequiresSecureSession() {
        var server = makeServer()
        let response = server.handle(
            request(.characteristicWrite, iid: 10, body: body([(.value, Data([50]))])),
            isSecured: false,
            now: now
        )
        #expect(response.status == .insufficientAuthentication)
        #expect(server.dataSource.writes.isEmpty)
    }

    @Test
    func writeValidatesConstraints() {
        var server = makeServer()
        // Brightness is limited to 0...100.
        let response = server.handle(
            request(.characteristicWrite, iid: 10, body: body([(.value, Data([200]))])),
            isSecured: true,
            now: now
        )
        #expect(response.status == .invalidRequest)
        #expect(server.dataSource.writes.isEmpty)
    }

    @Test
    func writeRejectsMalformedValue() {
        var server = makeServer()
        // A UInt8 characteristic requires exactly one value byte.
        let response = server.handle(
            request(.characteristicWrite, iid: 10, body: body([(.value, Data([1, 2]))])),
            isSecured: true,
            now: now
        )
        #expect(response.status == .invalidRequest)
        // A missing value parameter is also rejected.
        #expect(
            server.handle(
                request(.characteristicWrite, iid: 10, body: body([])),
                isSecured: true,
                now: now
            ).status == .invalidRequest
        )
    }

    @Test
    func writePassesAdditionalParameters() throws {
        var server = makeServer()
        let authorizationData = Data([0xAA, 0xBB])
        let response = server.handle(
            request(.characteristicWrite, iid: 10, body: body([
                (.value, Data([10])),
                (.additionalAuthorizationData, authorizationData),
                (.origin, Data([0x01]))  // remote
            ])),
            isSecured: true,
            now: now
        )
        #expect(response.status == .success)
        let write = try #require(server.dataSource.writes.first)
        #expect(write.context.authorizationData == authorizationData)
        #expect(write.context.remote)
    }

    @Test
    func writeIgnoresUnsupportedParameters() {
        var server = makeServer()
        var container = TLVContainer()
        container.items.append(TLVItem(type: TLVTypeCode(rawValue: 0x7F), value: .init(Data([0xFF]))))
        container.items.append(TLVItem(
            type: BLEPDUParamType.value.typeCode,
            value: .init(Data([33]))
        ))
        let response = server.handle(
            request(.characteristicWrite, iid: 10, body: Data(container.data)),
            isSecured: true,
            now: now
        )
        #expect(response.status == .success)
        #expect(server.dataSource.values[10] == .uint8(33))
    }

    @Test
    func writeRejectedWhenTimedWriteRequired() {
        var server = makeServer()
        let response = server.handle(
            request(.characteristicWrite, iid: 12, body: body([(.value, Data([1]))])),
            isSecured: true,
            now: now
        )
        #expect(response.status == .invalidRequest)
        #expect(server.dataSource.writes.isEmpty)
    }

    // MARK: Timed Writes

    @Test
    func timedWriteAndExecute() {
        var server = makeServer()
        let staged = server.handle(
            request(.characteristicTimedWrite, iid: 12, body: body([
                (.ttl, Data([50])),  // 5 seconds
                (.value, Data([1]))
            ])),
            isSecured: true,
            now: now
        )
        #expect(staged.status == .success)
        #expect(server.dataSource.writes.isEmpty)  // not yet applied

        let executed = server.handle(
            request(.characteristicExecuteWrite, iid: 12),
            isSecured: true,
            now: now.advanced(byMilliseconds: 1000)
        )
        #expect(executed.status == .success)
        #expect(server.dataSource.values[12] == .uint8(1))
    }

    @Test
    func timedWriteExpires() {
        var server = makeServer()
        _ = server.handle(
            request(.characteristicTimedWrite, iid: 12, body: body([
                (.ttl, Data([10])),  // 1 second
                (.value, Data([1]))
            ])),
            isSecured: true,
            now: now
        )
        let executed = server.handle(
            request(.characteristicExecuteWrite, iid: 12),
            isSecured: true,
            now: now.advanced(byMilliseconds: 1001)
        )
        #expect(executed.status == .invalidRequest)
        #expect(server.dataSource.writes.isEmpty)
    }

    @Test
    func timedWriteRequiresTTL() {
        var server = makeServer()
        let response = server.handle(
            request(.characteristicTimedWrite, iid: 12, body: body([(.value, Data([1]))])),
            isSecured: true,
            now: now
        )
        #expect(response.status == .invalidRequest)
    }

    @Test
    func executeWithoutStagedWrite() {
        var server = makeServer()
        let response = server.handle(
            request(.characteristicExecuteWrite, iid: 12),
            isSecured: true,
            now: now
        )
        #expect(response.status == .invalidRequest)
    }

    @Test
    func executeWithMismatchedInstanceID() {
        var server = makeServer()
        _ = server.handle(
            request(.characteristicTimedWrite, iid: 12, body: body([
                (.ttl, Data([50])),
                (.value, Data([1]))
            ])),
            isSecured: true,
            now: now
        )
        let executed = server.handle(
            request(.characteristicExecuteWrite, iid: 10),  // different characteristic
            isSecured: true,
            now: now
        )
        #expect(executed.status == .invalidRequest)
        #expect(server.dataSource.writes.isEmpty)
    }


    // MARK: Characteristic Configuration

    /// Instance ID 9 supports broadcast notifications in these tests.
    func makeBroadcastServer() -> BLEProcedureServer<MockCharacteristicDataSource, MockBLEConfigurationContext> {
        var server = makeServer()
        var accessory = server.accessory
        var services = accessory.services!
        var characteristics = services[1].characteristics!
        guard case var .bool(on) = characteristics[0] else { fatalError() }
        on.properties.insert(.bleSupportsBroadcastNotification)
        characteristics[0] = .bool(on)
        services[1].characteristics = characteristics
        accessory.services = services
        server.accessory = accessory
        return server
    }

    func configurationBody(properties: UInt16? = nil, interval: UInt8? = nil) -> Data {
        var container = TLVContainer()
        if let properties {
            container.items.append(TLVItem(
                type: TLVTypeCode(rawValue: 0x01),
                value: .init([UInt8(properties & 0xFF), UInt8(properties >> 8)])
            ))
        }
        if let interval {
            container.items.append(TLVItem(type: TLVTypeCode(rawValue: 0x02), value: .init([interval])))
        }
        return Data(container.data)
    }

    @Test
    func characteristicConfigurationEnablesBroadcasts() {
        var server = makeBroadcastServer()
        let response = server.handle(
            request(.characteristicConfiguration, iid: 9, body: configurationBody(properties: 0x0001, interval: 0x02)),
            isSecured: true,
            now: now
        )
        #expect(response.status == .success)
        #expect(server.configuration.broadcastConfigurations[9]?.isEnabled == true)
        #expect(server.configuration.broadcastConfigurations[9]?.interval == .milliseconds1280)
        // The response echoes all parameters (Table 7-31).
        #expect(Array(response.body ?? Data()) == [
            0x01, 0x02, 0x01, 0x00,
            0x02, 0x01, 0x02
        ])
    }

    @Test
    func characteristicConfigurationReadsDefaults() {
        var server = makeServer()
        let response = server.handle(
            request(.characteristicConfiguration, iid: 9, body: configurationBody()),
            isSecured: true,
            now: now
        )
        #expect(response.status == .success)
        #expect(Array(response.body ?? Data()) == [
            0x01, 0x02, 0x00, 0x00,   // broadcasts disabled
            0x02, 0x01, 0x01          // default interval 20 ms
        ])
    }

    @Test
    func characteristicConfigurationRejectsUnsupportedBroadcasts() {
        var server = makeServer()  // iid 9 does not support broadcast notifications here
        let response = server.handle(
            request(.characteristicConfiguration, iid: 9, body: configurationBody(properties: 0x0001)),
            isSecured: true,
            now: now
        )
        #expect(response.status == .invalidRequest)
    }

    @Test
    func characteristicConfigurationRejectsReservedBits() {
        var server = makeBroadcastServer()
        let response = server.handle(
            request(.characteristicConfiguration, iid: 9, body: configurationBody(properties: 0x0002)),
            isSecured: true,
            now: now
        )
        #expect(response.status == .invalidRequest)
    }

    @Test
    func characteristicConfigurationRequiresSecureSession() {
        var server = makeBroadcastServer()
        let response = server.handle(
            request(.characteristicConfiguration, iid: 9, body: configurationBody(properties: 0x0001)),
            isSecured: false,
            now: now
        )
        #expect(response.status == .insufficientAuthentication)
    }

    // MARK: Protocol Configuration

    func protocolBody(_ types: [UInt8], identifier: Data? = nil) -> Data {
        var container = TLVContainer()
        for type in types {
            container.items.append(TLVItem(
                type: TLVTypeCode(rawValue: type),
                value: .init(type == 0x03 ? (identifier ?? Data()) : Data())
            ))
        }
        return Data(container.data)
    }

    /// The HAP Protocol Information service (iid 20) supports configuration.
    func makeProtocolServer() -> BLEProcedureServer<MockCharacteristicDataSource, MockBLEConfigurationContext> {
        var server = makeServer()
        var accessory = server.accessory
        accessory.services!.append(Service(
            iid: 20,
            serviceType: .hapProtocolInformation,
            debugDescription: "protocol-information",
            properties: [.bleSupportsConfiguration]
        ))
        server.accessory = accessory
        return server
    }

    @Test
    func protocolConfigurationGetAllParams() {
        var server = makeProtocolServer()
        server.configuration.globalStateNumber = 0x1234
        server.configuration.configurationNumber = 7
        let response = server.handle(
            request(.protocolConfiguration, iid: 20, body: protocolBody([0x02])),
            isSecured: true,
            now: now
        )
        #expect(response.status == .success)
        #expect(Array(response.body ?? Data()) == [
            0x01, 0x02, 0x34, 0x12,                              // state number
            0x02, 0x01, 0x07,                                    // config number
            0x03, 0x06, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF       // advertising identifier
        ])
    }

    @Test
    func protocolConfigurationGeneratesBroadcastKey() {
        var server = makeProtocolServer()
        let response = server.handle(
            request(.protocolConfiguration, iid: 20, body: protocolBody([0x01])),
            isSecured: true,
            now: now
        )
        #expect(response.status == .success)
        #expect(server.configuration.keyGenerations == 1)
        // The 32-byte key is included as parameter 0x04.
        let body = Array(response.body ?? Data())
        #expect(body.suffix(34).prefix(2) == [0x04, 0x20])
        #expect(Array(body.suffix(32)) == [UInt8](repeating: 0x5A, count: 32))
    }

    @Test
    func protocolConfigurationSetsAdvertisingIdentifier() {
        var server = makeProtocolServer()
        let identifier = Data([1, 2, 3, 4, 5, 6])
        let response = server.handle(
            request(.protocolConfiguration, iid: 20, body: protocolBody([0x03], identifier: identifier)),
            isSecured: true,
            now: now
        )
        #expect(response.status == .success)
        #expect(server.configuration.advertisingIdentifier == identifier)
    }

    @Test
    func protocolConfigurationRequiresConfigurableService() {
        var server = makeProtocolServer()
        // The light bulb service does not have the configuration property.
        let response = server.handle(
            request(.protocolConfiguration, iid: 8, body: protocolBody([0x02])),
            isSecured: true,
            now: now
        )
        #expect(response.status == .invalidInstanceID)
    }

    @Test
    func protocolConfigurationRequiresSecureSession() {
        var server = makeProtocolServer()
        let response = server.handle(
            request(.protocolConfiguration, iid: 20, body: protocolBody([0x02])),
            isSecured: false,
            now: now
        )
        #expect(response.status == .insufficientAuthentication)
    }

    // MARK: Transaction IDs

    @Test
    func responsesEchoTransactionID() {
        var server = makeServer()
        for tid: UInt8 in [0x00, 0x7F, 0xFF] {
            let response = server.handle(
                request(.characteristicRead, iid: 10, tid: tid),
                isSecured: true,
                now: now
            )
            #expect(response.transactionID == tid)
        }
    }
}
