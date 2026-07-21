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
/// Advertising data is not part of the `PeripheralManager` protocol — it is configured by
/// the platform's Bluetooth stack. Feed ``advertisementData()`` to the platform when
/// starting to advertise and whenever ``BLEServerSession/advertisementData()`` changes.
public final class BLEPeripheralServer<
    Peripheral: PeripheralManager,
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

    /// Invoked when a connection is dropped because the request could not be handled.
    ///
    /// The transport should disconnect the central; the `PeripheralManager` protocol has no
    /// per-central disconnect, so this is surfaced for the platform to act on.
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
    }

    func didDisconnect(_ central: Peripheral.Central) {
        guard let connection = connections.removeValue(forKey: central.id) else { return }
        try? server.disconnect(connection)
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
            didDropConnection?(confirmation.central)
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
    ///
    /// Pass to the platform's advertising API — see the note on ``BLEPeripheralServer``.
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
