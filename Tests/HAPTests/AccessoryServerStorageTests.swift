import Testing
@testable import HAP

/// A deterministic random source for tests.
struct FixedRandomSource: RandomNumberSource {

    var byte: UInt8 = 0xAB

    func fill(_ buffer: inout [UInt8]) {
        for index in buffer.indices {
            buffer[index] = byte
        }
    }
}

@Suite
struct AccessoryServerStorageTests {

    func makeStorage(
        store: MockKeyValueStore = MockKeyValueStore()
    ) -> AccessoryServerStorage<MockKeyValueStore, FixedRandomSource> {
        AccessoryServerStorage(store: store, random: FixedRandomSource())
    }

    @Test
    func deviceIDIsGeneratedOnceAndPersists() throws {
        let store = MockKeyValueStore()
        let storage = makeStorage(store: store)
        let deviceID = try storage.deviceID()
        #expect(deviceID.count == 6)
        #expect(try storage.deviceID() == deviceID)
        // A new storage over the same backing store sees the same identity.
        #expect(try makeStorage(store: store).deviceID() == deviceID)
        #expect(try storage.deviceIDString() == "AB:AB:AB:AB:AB:AB")
    }

    @Test
    func deviceIDStringFormatsLowBytes() throws {
        let store = MockKeyValueStore()
        try store.setValue(
            Data([0x0A, 0x00, 0xFF, 0x01, 0x2B, 0x3C]),
            for: AccessoryServerStorageKey.deviceID,
            in: .configuration
        )
        #expect(try makeStorage(store: store).deviceIDString() == "0A:00:FF:01:2B:3C")
    }

    @Test
    func configurationNumberStartsAtOneAndWraps() throws {
        let store = MockKeyValueStore()
        let storage = makeStorage(store: store)
        #expect(try storage.configurationNumber() == 1)
        try storage.incrementConfigurationNumber()
        #expect(try storage.configurationNumber() == 2)
        // Wraps from 255 to 1.
        try store.setValue(Data([255]), for: .init(rawValue: 0x20), in: .configuration)
        try storage.incrementConfigurationNumber()
        #expect(try storage.configurationNumber() == 1)
    }

    @Test
    func globalStateNumberRoundtrip() throws {
        let storage = makeStorage()
        #expect(try storage.globalStateNumber() == .initial)
        var gsn = BLEAccessoryServerGSN.initial
        gsn.increment()
        try storage.setGlobalStateNumber(gsn)
        let restored = try storage.globalStateNumber()
        #expect(restored.gsn == 2)
        #expect(restored.didIncrement)
    }

    @Test
    func broadcastParametersRoundtrip() throws {
        let storage = makeStorage()
        #expect(try storage.broadcastParameters() == BLEBroadcastParameters())
        var parameters = BLEBroadcastParameters()
        parameters.advertisingID = Data([1, 2, 3, 4, 5, 6])
        try storage.setBroadcastParameters(parameters)
        #expect(try storage.broadcastParameters() == parameters)
    }

    @Test
    func removePairingStateKeepsIdentity() throws {
        let store = MockKeyValueStore()
        let storage = makeStorage(store: store)
        let deviceID = try storage.deviceID()
        let pairings = PairingStore(store: store)
        try pairings.add(Pairing(
            identifier: "controller",
            publicKey: Data([UInt8](repeating: 1, count: 32)),
            permissions: .admin
        ))
        var gsn = BLEAccessoryServerGSN.initial
        gsn.increment()
        try storage.setGlobalStateNumber(gsn)

        try storage.removePairingState()
        #expect(try !pairings.isPaired())
        // The GSN resets to 1, the identity survives.
        #expect(try storage.globalStateNumber() == .initial)
        #expect(try storage.deviceID() == deviceID)
    }
}
