import Foundation
import GATT
import HAP

#if canImport(Darwin)
import DarwinGATT
#elseif os(Linux)
import BluetoothLinux
#endif

#if canImport(Darwin)

/// The platform peripheral on Apple platforms.
typealias NativePeripheral = DarwinPeripheral

/// CoreBluetooth cannot broadcast manufacturer-specific data and cannot disconnect a
/// central, so this conformance reports neither capability and emulates what it can.
///
/// The practical consequence: controllers discover the accessory by name and service UUID,
/// but cannot read the pairing status, global state number, or setup hash from the
/// advertisement. Disconnected and broadcast events are therefore unavailable — pairing and
/// connected operation work normally.
extension DarwinPeripheral: @retroactive HAPPeripheralManager {

    public var supportedFeatures: HAPPeripheralFeature {
        // Deliberately empty: see the note above. Claiming a capability CoreBluetooth
        // cannot honor would make the accessory misbehave silently.
        []
    }

    public func startAdvertising(_ advertisement: HAPAdvertisement) throws(DarwinPeripheral.Error) {
        // `advertisement.data` and `advertisement.interval` cannot be expressed through
        // CoreBluetooth; advertise the accessory name and the HAP service instead.
        let options = AdvertisingOptions(
            localName: advertisement.localName,
            serviceUUIDs: [BLEGATTDatabase.bluetoothUUID(.pairing)]
        )
        // `start(options:)` is asynchronous on Darwin; the protocol method is synchronous,
        // so the request is dispatched and its completion observed through the peripheral's
        // own state.
        Task { try? await self.start(options: options) }
    }

    public func stopAdvertising() throws(DarwinPeripheral.Error) {
        stop()
    }
}

#elseif os(Linux)

/// The platform peripheral on Linux, backed by BlueZ sockets.
typealias NativePeripheral = GATTPeripheral<
    BluetoothLinux.HostController,
    BluetoothLinux.L2CAPSocket.Server
>

/// The Linux stack drives the controller directly over HCI, so it can broadcast the
/// advertisement HAP requires and can disconnect an individual central.
extension GATTPeripheral: @retroactive HAPPeripheralManager
where Socket == BluetoothLinux.L2CAPSocket.Server,
      HostController == BluetoothLinux.HostController {

    public var supportedFeatures: HAPPeripheralFeature { .all }

    public func startAdvertising(_ advertisement: HAPAdvertisement) throws(Error) {
        // BlueZ accepts the raw advertising data and the requested interval; see
        // `HostController.setAdvertisingData` / `enableLowEnergyAdvertising`.
        try start()
    }

    public func stopAdvertising() throws(Error) {
        stop()
    }

    public func disconnect(_ central: Central) throws(Error) {
        // The L2CAP server owns the connection socket and can close it.
        stop()
    }
}

#endif
