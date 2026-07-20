import FoundationEmbedded

/// Handles Add Pairing, Remove Pairing, and List Pairings requests received over a
/// verified session.
///
/// These procedures may only be performed by admin controllers over a session established
/// via Pair Verify. The caller is responsible for the transport-level side effects reported
/// in ``Response/effect`` (tearing down sessions of removed controllers, updating the
/// pairing state in advertisements).
///
/// - SeeAlso: HAP Specification R2, Sections 5.10 Add Pairing, 5.11 Remove Pairing,
///   5.12 List Pairings
public struct PairingsServer<Store: KeyValueStore> {

    /// A transport-level side effect of a pairings request.
    public enum Effect: Equatable, Hashable, Sendable {

        /// No side effect.
        case none

        /// A pairing was added or its permissions updated.
        case addedOrUpdated(Pairing)

        /// A pairing was removed. Existing sessions with the removed controller must be
        /// torn down within 5 seconds; if the controller removed its own pairing, the
        /// session must be invalidated after the response is sent.
        ///
        /// If `removedAllPairings` is `true`, the last admin was removed and all pairings
        /// were cleared — the accessory is now unpaired.
        case removed(identifier: String, removedAllPairings: Bool)
    }

    /// The response to a pairings request.
    public struct Response: Equatable {

        /// The response message.
        public let message: PairingTLV

        /// The transport-level side effect of the request.
        public let effect: Effect
    }

    private let store: PairingStore<Store>

    public init(store: PairingStore<Store>) {
        self.store = store
    }

    /// Processes a pairings request from the controller of a verified session.
    ///
    /// - Parameters:
    ///   - request: The request message.
    ///   - controllerIdentifier: The pairing identifier of the controller that established
    ///     the session via Pair Verify.
    public func handle(_ request: PairingTLV, controllerIdentifier: String) -> Response {
        guard request.state == 1, let method = request.method else {
            return .failure(.unknown)
        }
        // The requesting controller must have the admin bit set in the local pairings list.
        let controller: Pairing?
        do {
            controller = try store.pairing(for: controllerIdentifier)
        } catch {
            return .failure(.unknown)
        }
        guard let controller, controller.isAdmin else {
            return .failure(.authentication)
        }
        switch method {
        case .addPairing:
            return addPairing(request)
        case .removePairing:
            return removePairing(request)
        case .listPairings:
            return listPairings()
        case .pairSetup, .pairSetupWithAuth, .pairVerify:
            return .failure(.unknown)
        }
    }
}

private extension PairingsServer {

    /// Add Pairing (§5.10.2).
    func addPairing(_ request: PairingTLV) -> Response {
        guard let identifier = request.string(for: .identifier),
              let publicKey = request[.publicKey],
              let permissions = request.permissions,
              publicKey.count == 32,
              identifier.utf8.count <= Pairing.maximumIdentifierLength
        else { return .failure(.unknown) }
        do {
            let pairing = Pairing(identifier: identifier, publicKey: publicKey, permissions: permissions)
            if let existing = try store.pairing(for: identifier) {
                // The stored long-term public key must match; only permissions may change.
                guard existing.publicKey == publicKey else {
                    return .failure(.unknown)
                }
            }
            try store.add(pairing)
            return .success(effect: .addedOrUpdated(pairing))
        } catch HAPError.outOfResources {
            return .failure(.maxPeers)
        } catch {
            return .failure(.unknown)
        }
    }

    /// Remove Pairing (§5.11.2).
    func removePairing(_ request: PairingTLV) -> Response {
        guard let identifier = request.string(for: .identifier) else {
            return .failure(.unknown)
        }
        do {
            // Removing a pairing that does not exist is a success.
            guard try store.pairing(for: identifier) != nil else {
                return .success(effect: .none)
            }
            try store.remove(identifier)
            // If the last remaining admin controller pairing is removed, all pairings
            // on the accessory must be removed.
            var removedAllPairings = false
            if try !store.hasAdmin() {
                try store.removeAll()
                removedAllPairings = true
            }
            return .success(
                effect: .removed(identifier: identifier, removedAllPairings: removedAllPairings)
            )
        } catch {
            return .failure(.unknown)
        }
    }

    /// List Pairings (§5.12.2).
    func listPairings() -> Response {
        let pairings: [Pairing]
        do {
            pairings = try store.pairings()
        } catch {
            return .failure(.unknown)
        }
        var message = PairingTLV()
        message.append(integer: 2, for: .state)
        for (index, pairing) in pairings.enumerated() {
            if index > 0 {
                message.appendSeparator()
            }
            message.append(string: pairing.identifier, for: .identifier)
            message.append(pairing.publicKey, for: .publicKey)
            message.append(integer: UInt64(pairing.permissions.rawValue), for: .permissions)
        }
        return Response(message: message, effect: .none)
    }
}

private extension PairingsServer.Response {

    static func success(effect: PairingsServer.Effect) -> Self {
        var message = PairingTLV()
        message.append(integer: 2, for: .state)
        return .init(message: message, effect: effect)
    }

    static func failure(_ error: PairingError) -> Self {
        var message = PairingTLV()
        message.append(integer: 2, for: .state)
        message.append(integer: UInt64(error.rawValue), for: .error)
        return .init(message: message, effect: .none)
    }
}
