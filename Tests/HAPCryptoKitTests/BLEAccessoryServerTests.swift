import Testing
import TLVCoding
@testable import HAP
@testable import HAPCryptoKit

@Suite
struct BLEAccessoryServerTests {

    final class SystemClock: PlatformClock, @unchecked Sendable {
        var now: HAPTime { HAPTime(rawValue: 1000) }
    }

    struct SystemRandom: RandomNumberSource {
        func fill(_ buffer: inout [UInt8]) {
            for index in buffer.indices {
                buffer[index] = UInt8.random(in: .min ... .max)
            }
        }
    }

    let provider = SwiftCryptoProvider()

    func makeServer(
        store: MockServerKeyValueStore = MockServerKeyValueStore()
    ) throws -> BLEAccessoryServer<SwiftCryptoProvider, MockServerKeyValueStore, SystemRandom, ConnectionDataSource> {
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
        try accessory.validate(transport: .ble)
        let salt = Data(CryptoTestVectors.srpSalt)
        return try BLEAccessoryServer(
            accessory: accessory,
            crypto: provider,
            store: store,
            random: SystemRandom(),
            clock: SystemClock(),
            dataSource: ConnectionDataSource(values: [0x33: .bool(true)]),
            setupSalt: salt,
            setupVerifier: provider.srpVerifier(
                username: "Pair-Setup",
                password: "101-48-005",
                salt: salt
            )
        )
    }

    @Test
    func advertisesUnpairedState() throws {
        let server = try makeServer()
        let data = Array(try server.advertisementData())
        #expect(data.count == 26)
        #expect(data[7] == 0x06)   // regular advertisement
        #expect(data[9] == 0x01)   // status flags: not paired
        #expect(data[18] == 0x01)  // GSN = 1
    }

    @Test
    func identityPersistsAcrossRestarts() throws {
        let store = MockServerKeyValueStore()
        let first = try makeServer(store: store)
        let advertisement = Array(try first.advertisementData())
        let second = try makeServer(store: store)
        // Device ID bytes 10...15 are identical after a restart.
        #expect(Array(try second.advertisementData())[10 ... 15] == advertisement[10 ... 15])
    }

    @Test
    func pairSetupStartOverGATT() throws {
        let server = try makeServer()
        server.connect(1)

        var m1 = PairingTLV()
        m1.append(integer: 1, for: .state)
        m1.append(integer: UInt64(PairingMethod.pairSetup.rawValue), for: .method)
        var body = TLVContainer()
        body.items.append(TLVItem(type: BLEPDUParamType.value.typeCode, value: .init(m1.data)))
        let request = BLEPDURequest(
            opcode: .characteristicWrite,
            transactionID: 1,
            instanceID: 0x22,  // Pair Setup characteristic
            body: Data(body.data)
        )
        try server.handleWrite(connection: 1, characteristicIID: 0x22, data: request.data)
        let responseData = server.readResponse(connection: 1)
        let response = try BLEPDUResponse(data: try #require(responseData))
        #expect(response.status == .success)
        #expect(!server.isSecured(connection: 1))
    }

    @Test
    func stateChangesIncrementGSNOnlyWhileDisconnected() throws {
        let store = MockServerKeyValueStore()
        let server = try makeServer(store: store)
        try server.didChangeState()
        #expect(server.gsn.gsn == 2)
        // Only once per cycle.
        try server.didChangeState()
        #expect(server.gsn.gsn == 2)
        // Not while a controller is connected.
        server.connect(7)
        try server.didChangeState()
        #expect(server.gsn.gsn == 2)
        // Disconnecting ends the cycle; the next change increments again.
        try server.disconnect(7)
        try server.didChangeState()
        #expect(server.gsn.gsn == 3)
        // The GSN persists across restarts.
        #expect(try makeServer(store: store).gsn.gsn == 3)
    }

    @Test
    func unknownConnectionRejected() throws {
        let server = try makeServer()
        #expect(throws: HAPError.invalidState) {
            try server.handleWrite(connection: 99, characteristicIID: 0x33, data: Data([0x00]))
        }
    }
}

// MARK: -

/// In-memory key-value store for the server tests.
final class MockServerKeyValueStore: KeyValueStore {

    private var storage: [KeyValueStoreDomain: [KeyValueStoreKey: Data]] = [:]

    func value(for key: KeyValueStoreKey, in domain: KeyValueStoreDomain) throws(HAPError) -> Data? {
        storage[domain]?[key]
    }

    func setValue(_ value: Data, for key: KeyValueStoreKey, in domain: KeyValueStoreDomain) throws(HAPError) {
        storage[domain, default: [:]][key] = value
    }

    func removeValue(for key: KeyValueStoreKey, in domain: KeyValueStoreDomain) throws(HAPError) {
        storage[domain]?[key] = nil
    }

    func enumerateKeys(
        in domain: KeyValueStoreDomain,
        _ body: (KeyValueStoreKey) throws(HAPError) -> Bool
    ) throws(HAPError) {
        for key in (storage[domain] ?? [:]).keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard try body(key) else { return }
        }
    }

    func removeAll(in domain: KeyValueStoreDomain) throws(HAPError) {
        storage[domain] = nil
    }
}
