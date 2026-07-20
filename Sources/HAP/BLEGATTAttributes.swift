import BluetoothGATT

/// Maps an accessory's attribute database to the GATT services a peripheral registers.
///
/// This is the bridge between ``BLEGATTDatabase`` and a `PeripheralManager` from
/// PureSwift/GATT: the returned services can be passed to `add(service:)`, and the returned
/// handles mapped back to HAP instance IDs. HAP-BLE security is enforced by the PDU
/// procedures, so the GATT characteristics carry plain read/write permissions.
///
/// - SeeAlso: HAP Specification R2, Sections 7.4.3 – 7.4.4
public extension BLEGATTDatabase {

    /// The GATT services for an accessory, as `GATTAttribute` values.
    ///
    /// - Parameter type: The byte-container type of the target `PeripheralManager`.
    static func gattServices<Bytes: DataContainer>(
        for accessory: Accessory,
        as type: Bytes.Type = Bytes.self
    ) -> [GATTAttribute<Bytes>.Service] {
        services(for: accessory).map { service in
            var characteristics: [GATTAttribute<Bytes>.Characteristic] = [
                // The Service Instance ID characteristic carries a static value.
                GATTAttribute.Characteristic(
                    uuid: bluetoothUUID(serviceInstanceIDCharacteristicType),
                    value: Bytes(service.instanceIDValue),
                    permissions: [.read],
                    properties: [.read]
                )
            ]
            for characteristic in service.characteristics {
                var properties: GATTCharacteristicProperties = [.read, .write]
                if characteristic.supportsIndication {
                    properties.insert(.indicate)
                }
                characteristics.append(GATTAttribute.Characteristic(
                    uuid: bluetoothUUID(characteristic.type),
                    value: Bytes(),
                    permissions: [.read, .write],
                    properties: properties,
                    descriptors: [
                        // The Characteristic Instance ID descriptor carries a static value.
                        GATTAttribute.Descriptor(
                            uuid: bluetoothUUID(characteristicInstanceIDDescriptorType),
                            value: Bytes(characteristic.instanceIDValue),
                            permissions: [.read]
                        )
                    ]
                ))
            }
            return GATTAttribute.Service(
                uuid: bluetoothUUID(service.type),
                isPrimary: true,
                characteristics: characteristics
            )
        }
    }

    /// Converts a HAP UUID to a Bluetooth 128-bit UUID.
    static func bluetoothUUID(_ uuid: HAPUUID) -> BluetoothUUID {
        .bit128(UInt128(bigEndian: UInt128(bytes: uuid.rawValue.uuid)))
    }
}
