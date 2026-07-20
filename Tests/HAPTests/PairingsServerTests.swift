import Testing
@testable import HAP

@Suite
struct PairingsServerTests {

    let store = PairingStore(store: MockKeyValueStore())

    func makeServer() -> PairingsServer<MockKeyValueStore> {
        PairingsServer(store: store)
    }

    func addAdmin(_ identifier: String = "admin") throws {
        try store.add(Pairing(
            identifier: identifier,
            publicKey: Data([UInt8](repeating: 0xAA, count: 32)),
            permissions: .admin
        ))
    }

    func addRequest(
        _ identifier: String,
        keyByte: UInt8 = 0xBB,
        permissions: PairingPermissions = []
    ) -> PairingTLV {
        var request = PairingTLV()
        request.append(integer: 1, for: .state)
        request.append(integer: UInt64(PairingMethod.addPairing.rawValue), for: .method)
        request.append(string: identifier, for: .identifier)
        request.append(Data([UInt8](repeating: keyByte, count: 32)), for: .publicKey)
        request.append(integer: UInt64(permissions.rawValue), for: .permissions)
        return request
    }

    func removeRequest(_ identifier: String) -> PairingTLV {
        var request = PairingTLV()
        request.append(integer: 1, for: .state)
        request.append(integer: UInt64(PairingMethod.removePairing.rawValue), for: .method)
        request.append(string: identifier, for: .identifier)
        return request
    }

    var listRequest: PairingTLV {
        var request = PairingTLV()
        request.append(integer: 1, for: .state)
        request.append(integer: UInt64(PairingMethod.listPairings.rawValue), for: .method)
        return request
    }

    // MARK: Admin Enforcement

    @Test
    func rejectsNonAdmin() throws {
        try addAdmin()
        try store.add(Pairing(
            identifier: "user",
            publicKey: Data([UInt8](repeating: 0xBB, count: 32)),
            permissions: []
        ))
        let server = makeServer()
        for request in [addRequest("new"), removeRequest("admin"), listRequest] {
            let response = server.handle(request, controllerIdentifier: "user")
            #expect(response.message.state == 2)
            #expect(response.message.error == .authentication)
            #expect(response.effect == .none)
        }
        // Unpaired controllers are rejected the same way.
        let response = makeServer().handle(listRequest, controllerIdentifier: "stranger")
        #expect(response.message.error == .authentication)
    }

    // MARK: Add Pairing

    @Test
    func addPairing() throws {
        try addAdmin()
        let response = makeServer().handle(addRequest("new"), controllerIdentifier: "admin")
        #expect(response.message.state == 2)
        #expect(response.message.error == nil)
        let added = try #require(try store.pairing(for: "new"))
        #expect(!added.isAdmin)
        #expect(response.effect == .addedOrUpdated(added))
    }

    @Test
    func addPairingUpdatesPermissions() throws {
        try addAdmin()
        let server = makeServer()
        _ = server.handle(addRequest("new", keyByte: 0xBB), controllerIdentifier: "admin")
        let response = server.handle(
            addRequest("new", keyByte: 0xBB, permissions: .admin),
            controllerIdentifier: "admin"
        )
        #expect(response.message.error == nil)
        #expect(try store.pairing(for: "new")?.isAdmin == true)
    }

    @Test
    func addPairingRejectsKeyMismatch() throws {
        try addAdmin()
        let server = makeServer()
        _ = server.handle(addRequest("new", keyByte: 0xBB), controllerIdentifier: "admin")
        // Same identifier, different long-term public key.
        let response = server.handle(addRequest("new", keyByte: 0xCC), controllerIdentifier: "admin")
        #expect(response.message.error == .unknown)
        #expect(try store.pairing(for: "new")?.publicKey.first == 0xBB)
    }

    @Test
    func addPairingRejectsWhenFull() throws {
        let smallStore = PairingStore(store: MockKeyValueStore(), capacity: 1)
        try smallStore.add(Pairing(
            identifier: "admin",
            publicKey: Data([UInt8](repeating: 0xAA, count: 32)),
            permissions: .admin
        ))
        let server = PairingsServer(store: smallStore)
        let response = server.handle(addRequest("new"), controllerIdentifier: "admin")
        #expect(response.message.error == .maxPeers)
    }

    // MARK: Remove Pairing

    @Test
    func removePairing() throws {
        try addAdmin()
        try store.add(Pairing(
            identifier: "user",
            publicKey: Data([UInt8](repeating: 0xBB, count: 32)),
            permissions: []
        ))
        let response = makeServer().handle(removeRequest("user"), controllerIdentifier: "admin")
        #expect(response.message.state == 2)
        #expect(response.message.error == nil)
        #expect(response.effect == .removed(identifier: "user", removedAllPairings: false))
        #expect(try store.pairing(for: "user") == nil)
        #expect(try store.isPaired())
    }

    @Test
    func removeNonexistentPairingSucceeds() throws {
        try addAdmin()
        let response = makeServer().handle(removeRequest("ghost"), controllerIdentifier: "admin")
        #expect(response.message.error == nil)
        #expect(response.effect == .none)
    }

    @Test
    func removingLastAdminRemovesAllPairings() throws {
        try addAdmin()
        try store.add(Pairing(
            identifier: "user",
            publicKey: Data([UInt8](repeating: 0xBB, count: 32)),
            permissions: []
        ))
        let response = makeServer().handle(removeRequest("admin"), controllerIdentifier: "admin")
        #expect(response.message.error == nil)
        #expect(response.effect == .removed(identifier: "admin", removedAllPairings: true))
        #expect(try !store.isPaired())
    }

    // MARK: List Pairings

    @Test
    func listPairings() throws {
        try addAdmin()
        try store.add(Pairing(
            identifier: "user",
            publicKey: Data([UInt8](repeating: 0xBB, count: 32)),
            permissions: []
        ))
        let response = makeServer().handle(listRequest, controllerIdentifier: "admin")
        #expect(response.message.state == 2)
        #expect(response.message.error == nil)

        // Entries are identifier + publicKey + permissions, delimited by separators.
        let items = response.message.items
        let separators = items.filter { $0.type == .separator }
        let identifiers = items.filter { $0.type == .identifier }
        #expect(separators.count == 1)
        #expect(identifiers.count == 2)
        #expect(items.filter { $0.type == .publicKey }.count == 2)
        #expect(items.filter { $0.type == .permissions }.count == 2)
        // The separator sits between the two entries.
        let firstIdentifierIndex = try #require(items.firstIndex { $0.type == .identifier })
        let separatorIndex = try #require(items.firstIndex { $0.type == .separator })
        let lastIdentifierIndex = try #require(items.lastIndex { $0.type == .identifier })
        #expect(firstIdentifierIndex < separatorIndex)
        #expect(separatorIndex < lastIdentifierIndex)
    }
}
