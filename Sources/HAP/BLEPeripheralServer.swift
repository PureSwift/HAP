import GATT

/// Binds a HAP accessory server to a GATT peripheral.
///
/// Registers the accessory's attribute database with the peripheral, maps GATT attribute
/// handles to HAP instance IDs, and routes the peripheral's callbacks into the server:
///
/// | GATT | HAP |
/// | --- | --- |
/// | `didConnect` | ``BLEServerSession/connect(_:)`` |
/// | `didDisconnect` | ``BLEServerSession/disconnect(_:)`` |
/// | `didWrite` | ``BLEServerSession/handleWrite(connection:characteristicIID:data:)`` |
/// | `willRead` | ``BLEServerSession/readResponse(connection:)`` |
///
/// HAP-BLE is write-then-read on the same characteristic: the controller writes a request
/// PDU and then reads the staged response.
///
/// Advertising is managed automatically: the binding advertises the accessory's current
/// state, stops while a controller is connected, and resumes on disconnect. Capabilities the
/// peripheral does not provide — see ``HAPPeripheralManager/supportedFeatures`` — are
/// skipped rather than faked.
public final class BLEPeripheralServer<
    Peripheral: HAPPeripheralManager,
    Server: BLEServerSession
> {

    /// The GATT peripheral.
    public let peripheral: Peripheral

    /// The HAP accessory server.
    public let server: Server

    /// Maps a GATT characteristic value handle to its HAP characteristic instance ID.
    private var instanceIDs: [UInt16: UInt16] = [:]

    /// Maps a connected central to its HAP connection identifier.
    private var connections: [Peripheral.Central.ID: UInt64] = [:]

    /// The connection identifier assigned to the next central that connects.
    private var nextConnection: UInt64 = 1

    /// Invoked when a connection is dropped because a request could not be handled.
    ///
    /// The binding already asked the peripheral to disconnect the central; this reports the
    /// event for logging or platform-specific recovery.
    public var didDropConnection: ((Peripheral.Central) -> Void)?

    public init(peripheral: Peripheral, server: Server) {
        self.peripheral = peripheral
        self.server = server
    }

    /// Registers the accessory's services with the peripheral and installs the callbacks.
    ///
    /// Call before starting the peripheral.
    public func register() throws(Peripheral.Error) {
        var peripheral = self.peripheral
        for service in BLEGATTDatabase.gattServices(for: server.accessory, as: Peripheral.Data.self) {
            let added = try peripheral.add(service: service)
            map(added, of: service)
        }
        install(on: &peripheral)
    }

    /// Advertises the accessory's current state.
    ///
    /// Called automatically on ``register()`` and whenever a controller disconnects; call
    /// it after changing state that appears in the advertisement, such as the global state
    /// number or the pairing status.
    ///
    /// Does nothing while a controller is connected, since an accessory must not advertise
    /// during a connection.
    public func updateAdvertising() throws(HAPError) {
        guard !isConnected else { return }
        let advertisement = HAPAdvertisement(
            data: try server.advertisementData(),
            localName: server.accessory.name
        )
        try? peripheral.startAdvertising(advertisement)
    }
}

// MARK: - Attribute Mapping

private extension BLEPeripheralServer {

    /// Records the HAP instance ID of each added characteristic.
    ///
    /// The Characteristic Instance ID descriptor carries the instance ID as a little-endian
    /// `UInt16`, so the mapping is read back from the attribute values just registered.
    func map(
        _ added: GATTAddedService,
        of service: GATTAttribute<Peripheral.Data>.Service
    ) {
        for (index, characteristic) in added.characteristics.enumerated() {
            guard index < service.characteristics.count else { continue }
            let descriptors = service.characteristics[index].descriptors
            guard let descriptor = descriptors.first(where: { $0.value.count == 2 }),
                  descriptor.value.count == 2
            else { continue }
            let bytes = Array(descriptor.value)
            instanceIDs[characteristic.handle] = UInt16(bytes[0]) | UInt16(bytes[1]) << 8
        }
    }
}

// MARK: - Callbacks

private extension BLEPeripheralServer {

    func install(on peripheral: inout Peripheral) {
        peripheral.didConnect = { [weak self] central in
            self?.didConnect(central)
        }
        peripheral.didDisconnect = { [weak self] central in
            self?.didDisconnect(central)
        }
        peripheral.didWrite = { [weak self] confirmation in
            self?.didWrite(confirmation)
        }
        peripheral.willRead = { [weak self] request in
            self?.willRead(request) ?? .failure(.unlikelyError)
        }
    }

    func didConnect(_ central: Peripheral.Central) {
        let connection = nextConnection
        nextConnection &+= 1
        connections[central.id] = connection
        server.connect(connection)
        // An accessory must not advertise while a controller is connected.
        try? peripheral.stopAdvertising()
    }

    func didDisconnect(_ central: Peripheral.Central) {
        guard let connection = connections.removeValue(forKey: central.id) else { return }
        try? server.disconnect(connection)
        try? updateAdvertising()
    }

    func didWrite(_ confirmation: GATTWriteConfirmation<Peripheral.Central, Peripheral.Data>) {
        guard let connection = connections[confirmation.central.id],
              let instanceID = instanceIDs[confirmation.handle]
        else { return }
        do {
            try server.handleWrite(
                connection: connection,
                characteristicIID: instanceID,
                data: Data(confirmation.value)
            )
        } catch {
            // The connection is unrecoverable; the central must reconnect.
            connections[confirmation.central.id] = nil
            try? peripheral.disconnect(confirmation.central)
            didDropConnection?(confirmation.central)
            try? updateAdvertising()
        }
    }

    func willRead(
        _ request: GATTReadRequest<Peripheral.Central, Peripheral.Data>
    ) -> Result<Peripheral.Data, ATTError> {
        // Attributes without a HAP instance ID — the Service Instance ID characteristic and
        // the instance ID descriptors — serve their static value from the database.
        guard instanceIDs[request.handle] != nil else {
            return .success(request.value)
        }
        guard let connection = connections[request.central.id],
              let response = server.readResponse(connection: connection)
        else {
            // No staged response: the controller read without a preceding request.
            return .success(Peripheral.Data())
        }
        return .success(Peripheral.Data(response))
    }
}

// MARK: - Advertising

public extension BLEPeripheralServer {

    /// The regular advertisement payload for the current accessory state.
    func advertisementData() throws(HAPError) -> Data {
        try server.advertisementData()
    }

    /// Whether a controller is currently connected.
    ///
    /// An accessory must not advertise while a controller is connected.
    ///
    /// - SeeAlso: HAP Specification R2, Section 7.4.1.4 Advertising Interval
    var isConnected: Bool {
        !connections.isEmpty
    }
}
