import GATT
@testable import HAP

/// An in-memory `PeripheralManager` for testing transport bindings without a Bluetooth stack.
final class MockPeripheralManager: HAPPeripheralManager, @unchecked Sendable {

    typealias Central = GATT.Central
    typealias Data = [UInt8]
    typealias Error = MockPeripheralError

    var log: (@Sendable (String) -> ())?
    var willRead: ((GATTReadRequest<Central, Data>) -> Result<Data, ATTError>)?
    var willWrite: ((GATTWriteRequest<Central, Data>) -> ATTError?)?
    var didWrite: ((GATTWriteConfirmation<Central, Data>) -> ())?
    var didConnect: ((Central) -> ())?
    var didDisconnect: ((Central) -> ())?
    var didConfirm: ((Central, UInt16) -> ())?

    var isAdvertising = false
    private(set) var values: [UInt16: Data] = [:]
    private(set) var addedServices: [GATTAttribute<Data>.Service] = []

    /// Values written to characteristics via `write(_:forCharacteristic:)`, in order.
    private(set) var notifications: [(handle: UInt16, value: Data)] = []

    private var nextHandle: UInt16 = 1

    // MARK: HAP Peripheral

    /// The capabilities this mock reports; defaults to a fully capable stack.
    var supportedFeatures: HAPPeripheralFeature = .all

    /// Advertisements passed to `startAdvertising(_:)`, in order.
    private(set) var advertisements: [HAPAdvertisement] = []

    /// Centrals passed to `disconnect(_:)`, in order.
    private(set) var disconnected: [Central] = []

    func startAdvertising(_ advertisement: HAPAdvertisement) throws(Error) {
        advertisements.append(advertisement)
        isAdvertising = true
    }

    func stopAdvertising() throws(Error) {
        isAdvertising = false
    }

    func disconnect(_ central: Central) throws(Error) {
        disconnected.append(central)
    }

    func start() throws(Error) {
        isAdvertising = true
    }

    func stop() {
        isAdvertising = false
    }

    func add(service: GATTAttribute<Data>.Service) throws(Error) -> GATTAddedService {
        addedServices.append(service)
        let serviceHandle = claimHandle()
        var characteristics: [GATTAddedService.AddedCharacteristic] = []
        for characteristic in service.characteristics {
            _ = claimHandle()  // the characteristic declaration
            let valueHandle = claimHandle()
            values[valueHandle] = characteristic.value
            var descriptorHandles: [UInt16] = []
            for descriptor in characteristic.descriptors {
                let handle = claimHandle()
                values[handle] = descriptor.value
                descriptorHandles.append(handle)
            }
            characteristics.append(
                GATTAddedService.AddedCharacteristic(
                    handle: valueHandle,
                    descriptors: descriptorHandles
                )
            )
        }
        return GATTAddedService(handle: serviceHandle, characteristics: characteristics)
    }

    func remove(service: UInt16) {}

    func removeAllServices() {
        addedServices.removeAll()
        values.removeAll()
    }

    func write(_ newValue: Data, forCharacteristic handle: UInt16) {
        values[handle] = newValue
        notifications.append((handle, newValue))
    }

    func write(_ newValue: Data, forCharacteristic handle: UInt16, for central: Central) throws(Error) {
        write(newValue, forCharacteristic: handle)
    }

    subscript(characteristic handle: UInt16) -> Data {
        values[handle] ?? []
    }

    func value(for characteristicHandle: UInt16, central: Central) throws(Error) -> Data {
        values[characteristicHandle] ?? []
    }

    func maximumTransmissionUnit(for central: Central) throws(Error) -> MaximumTransmissionUnit {
        .default
    }

    private func claimHandle() -> UInt16 {
        defer { nextHandle += 1 }
        return nextHandle
    }

    // MARK: Test Driving

    /// Simulates a central connecting.
    func simulateConnect(_ central: Central) {
        didConnect?(central)
    }

    /// Simulates a central disconnecting.
    func simulateDisconnect(_ central: Central) {
        didDisconnect?(central)
    }

    /// Simulates a GATT write from a central.
    func simulateWrite(_ value: Data, handle: UInt16, from central: Central) {
        values[handle] = value
        didWrite?(GATTWriteConfirmation(
            central: central,
            maximumUpdateValueLength: 512,
            uuid: .bit16(0),
            handle: handle,
            value: value
        ))
    }

    /// Simulates a GATT read from a central, returning the served value.
    func simulateRead(handle: UInt16, from central: Central) -> Result<Data, ATTError> {
        let request = GATTReadRequest(
            central: central,
            maximumUpdateValueLength: 512,
            uuid: .bit16(0),
            handle: handle,
            value: values[handle] ?? [],
            offset: 0
        )
        return willRead?(request) ?? .success(values[handle] ?? [])
    }

    /// The value handle of the characteristic with the given HAP instance ID.
    ///
    /// Mirrors the handle assignment of ``add(service:)``.
    func handle(forInstanceID instanceID: UInt16) -> UInt16? {
        var handle: UInt16 = 1
        for service in addedServices {
            handle += 1  // service declaration
            for characteristic in service.characteristics {
                handle += 1  // characteristic declaration
                let valueHandle = handle
                handle += 1
                for descriptor in characteristic.descriptors {
                    if descriptor.value.count == 2 {
                        let value = UInt16(descriptor.value[0]) | UInt16(descriptor.value[1]) << 8
                        if value == instanceID { return valueHandle }
                    }
                    handle += 1
                }
            }
        }
        return nil
    }
}

// MARK: -

enum MockPeripheralError: Swift.Error {
    case unavailable
}
