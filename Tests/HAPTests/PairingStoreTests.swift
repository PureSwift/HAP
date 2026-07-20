import Testing
@testable import HAP

@Suite
struct PairingStoreTests {

    func makePairing(
        _ identifier: String,
        permissions: PairingPermissions = .admin,
        keyByte: UInt8 = 0xAA
    ) -> Pairing {
        Pairing(
            identifier: identifier,
            publicKey: Data([UInt8](repeating: keyByte, count: 32)),
            permissions: permissions
        )
    }

    @Test
    func storageRoundtrip() throws {
        let pairing = makePairing("E9E23DA1-3DDC-4A54-9F46-8663FB4CE1F1")
        let data = pairing.storageData
        #expect(data.count == Pairing.storageSize)
        let decoded = try #require(Pairing(storageData: data))
        #expect(decoded == pairing)
    }

    @Test
    func addAndLookup() throws {
        let store = PairingStore(store: MockKeyValueStore())
        #expect(try !store.isPaired())
        #expect(try !store.hasAdmin())

        let admin = makePairing("admin", permissions: .admin)
        let user = makePairing("user", permissions: [], keyByte: 0xBB)
        try store.add(admin)
        try store.add(user)

        #expect(try store.isPaired())
        #expect(try store.hasAdmin())
        #expect(try store.pairing(for: "admin") == admin)
        #expect(try store.pairing(for: "user") == user)
        #expect(try store.pairing(for: "other") == nil)
        #expect(try store.pairings().count == 2)
    }

    @Test
    func updateReplacesExisting() throws {
        let store = PairingStore(store: MockKeyValueStore())
        try store.add(makePairing("controller", permissions: .admin))
        try store.add(makePairing("controller", permissions: []))
        #expect(try store.pairings().count == 1)
        #expect(try store.pairing(for: "controller")?.isAdmin == false)
    }

    @Test
    func removeIsIdempotent() throws {
        let store = PairingStore(store: MockKeyValueStore())
        try store.add(makePairing("controller"))
        try store.remove("controller")
        #expect(try !store.isPaired())
        try store.remove("controller")  // no error
    }

    @Test
    func capacity() throws {
        let store = PairingStore(store: MockKeyValueStore(), capacity: 2)
        try store.add(makePairing("one"))
        try store.add(makePairing("two"))
        #expect(throws: HAPError.outOfResources) {
            try store.add(makePairing("three"))
        }
        // Updating an existing pairing does not require free space.
        try store.add(makePairing("two", permissions: []))
        // Removing frees a slot.
        try store.remove("one")
        try store.add(makePairing("three"))
    }
}
