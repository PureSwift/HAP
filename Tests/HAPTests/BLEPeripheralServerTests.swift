import Testing
import GATT
@testable import HAP

@Suite
struct BLEPeripheralServerTests {

    /// A stub server recording the calls the binding routes to it.
    final class StubServer: BLEServerSession {

        var accessory: Accessory
        var connected: [UInt64] = []
        var disconnected: [UInt64] = []
        var writes: [(connection: UInt64, iid: UInt16, data: Data)] = []
        var stagedResponse: Data?
        var writeError: HAPError?

        init(accessory: Accessory) {
            self.accessory = accessory
        }

        func connect(_ connection: UInt64) {
            connected.append(connection)
        }

        func disconnect(_ connection: UInt64) throws(HAPError) {
            disconnected.append(connection)
        }

        func handleWrite(
            connection: UInt64,
            characteristicIID: UInt16,
            data: Data
        ) throws(HAPError) {
            if let writeError { throw writeError }
            writes.append((connection, characteristicIID, data))
        }

        func readResponse(connection: UInt64) -> Data? {
            defer { stagedResponse = nil }
            return stagedResponse
        }

        func advertisementData() throws(HAPError) -> Data {
            Data([0x02, 0x01, 0x06])
        }
    }

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

    func makeBinding() throws -> (
        binding: BLEPeripheralServer<MockPeripheralManager, StubServer>,
        peripheral: MockPeripheralManager,
        server: StubServer
    ) {
        let peripheral = MockPeripheralManager()
        let server = StubServer(accessory: accessory)
        let binding = BLEPeripheralServer(peripheral: peripheral, server: server)
        try binding.register()
        return (binding, peripheral, server)
    }

    let central = GATT.Central(id: .min)

    @Test
    func registersAllServices() throws {
        let (binding, peripheral, _) = try makeBinding()
        _ = binding
        // Accessory Information, HAP Protocol Information, Pairing, Light Bulb.
        #expect(peripheral.addedServices.count == 4)
        // Every service leads with its Service Instance ID characteristic.
        for service in peripheral.addedServices {
            #expect(service.characteristics.first?.value.count == 2)
        }
    }

    @Test
    func connectAndDisconnectAreRouted() throws {
        let (binding, peripheral, server) = try makeBinding()
        #expect(!binding.isConnected)

        peripheral.simulateConnect(central)
        #expect(server.connected == [1])
        #expect(binding.isConnected)

        peripheral.simulateDisconnect(central)
        #expect(server.disconnected == [1])
        #expect(!binding.isConnected)

        // A second connection gets a fresh identifier.
        peripheral.simulateConnect(central)
        #expect(server.connected == [1, 2])
    }

    @Test
    func writeIsRoutedWithInstanceID() throws {
        let (binding, peripheral, server) = try makeBinding()
        defer { _ = binding }
        peripheral.simulateConnect(central)
        let handle = try #require(peripheral.handle(forInstanceID: 0x33))

        peripheral.simulateWrite([0x00, 0x03, 0x01, 0x33, 0x00], handle: handle, from: central)
        #expect(server.writes.count == 1)
        let write = try #require(server.writes.first)
        #expect(write.connection == 1)
        #expect(write.iid == 0x33)
        #expect(Array(write.data) == [0x00, 0x03, 0x01, 0x33, 0x00])
    }

    @Test
    func writeFromUnknownCentralIsIgnored() throws {
        let (binding, peripheral, server) = try makeBinding()
        defer { _ = binding }
        let handle = try #require(peripheral.handle(forInstanceID: 0x33))
        // No connect first.
        peripheral.simulateWrite([0x00], handle: handle, from: central)
        #expect(server.writes.isEmpty)
    }

    @Test
    func readServesStagedResponse() throws {
        let (binding, peripheral, server) = try makeBinding()
        defer { _ = binding }
        peripheral.simulateConnect(central)
        let handle = try #require(peripheral.handle(forInstanceID: 0x33))
        server.stagedResponse = Data([0x02, 0x03, 0x00])

        let result = peripheral.simulateRead(handle: handle, from: central)
        #expect(try result.get() == [0x02, 0x03, 0x00])

        // A second read with no staged response yields empty data.
        let empty = peripheral.simulateRead(handle: handle, from: central)
        #expect(try empty.get() == [])
    }

    /// Instance ID attributes are served from the GATT database, not the HAP server.
    @Test
    func staticAttributesServeStoredValue() throws {
        let (binding, peripheral, server) = try makeBinding()
        defer { _ = binding }
        peripheral.simulateConnect(central)
        server.stagedResponse = Data([0xFF])
        // Handle 2 is the first Service Instance ID characteristic value.
        let result = peripheral.simulateRead(handle: 2, from: central)
        #expect(try result.get() != [0xFF])
    }

    @Test
    func failedWriteDropsConnection() throws {
        let (binding, peripheral, server) = try makeBinding()
        var dropped: GATT.Central?
        binding.didDropConnection = { dropped = $0 }
        peripheral.simulateConnect(central)
        let handle = try #require(peripheral.handle(forInstanceID: 0x33))

        server.writeError = .notAuthorized
        peripheral.simulateWrite([0x00], handle: handle, from: central)
        #expect(dropped?.id == central.id)
        #expect(!binding.isConnected)

        // Subsequent writes from the dropped central are ignored.
        server.writeError = nil
        peripheral.simulateWrite([0x00], handle: handle, from: central)
        #expect(server.writes.isEmpty)
    }

    // MARK: Advertising

    @Test
    func advertisingStopsWhileConnectedAndResumes() throws {
        let (binding, peripheral, _) = try makeBinding()
        try binding.updateAdvertising()
        #expect(peripheral.isAdvertising)
        #expect(peripheral.advertisements.count == 1)
        // The advertisement carries the accessory's state and name.
        #expect(peripheral.advertisements[0].localName == "Light")

        // An accessory must not advertise while a controller is connected.
        peripheral.simulateConnect(central)
        #expect(!peripheral.isAdvertising)

        // Advertising is a no-op while connected, even if asked.
        try binding.updateAdvertising()
        #expect(!peripheral.isAdvertising)
        #expect(peripheral.advertisements.count == 1)

        // Disconnecting resumes advertising with fresh state.
        peripheral.simulateDisconnect(central)
        #expect(peripheral.isAdvertising)
        #expect(peripheral.advertisements.count == 2)
    }

    @Test
    func failedWriteDisconnectsCentral() throws {
        let (binding, peripheral, server) = try makeBinding()
        defer { _ = binding }
        peripheral.simulateConnect(central)
        let handle = try #require(peripheral.handle(forInstanceID: 0x33))

        server.writeError = .notAuthorized
        peripheral.simulateWrite([0x00], handle: handle, from: central)
        // The peripheral is asked to drop the central, and advertising resumes.
        #expect(peripheral.disconnected.map(\.id) == [central.id])
        #expect(peripheral.isAdvertising)
    }

    /// A stack without the HAP capabilities still works; the features report the gap.
    @Test
    func degradedPeripheralReportsCapabilities() throws {
        let (binding, peripheral, _) = try makeBinding()
        peripheral.supportedFeatures = []
        #expect(!peripheral.canAdvertiseAccessoryState)
        #expect(!peripheral.canBroadcastEvents)

        // Advertising and connections still function.
        try binding.updateAdvertising()
        peripheral.simulateConnect(central)
        #expect(binding.isConnected)

        // A fully capable stack reports both.
        peripheral.supportedFeatures = .all
        #expect(peripheral.canAdvertiseAccessoryState)
        #expect(peripheral.canBroadcastEvents)
    }

    @Test
    func advertisementDataIsForwarded() throws {
        let (binding, _, _) = try makeBinding()
        #expect(Array(try binding.advertisementData()) == [0x02, 0x01, 0x06])
    }
}
