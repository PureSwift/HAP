/// The GATT database layout of a HAP accessory.
///
/// Describes the services, characteristics, and descriptors a BLE transport must register
/// with its peripheral implementation:
/// - Each HAP service becomes a primary GATT service with a static, read-only
///   Service Instance ID characteristic.
/// - Each HAP characteristic becomes a GATT characteristic (readable and writable at the
///   GATT level — HAP-BLE security is enforced by the PDU procedures, not by GATT) with a
///   static, read-only Characteristic Instance ID descriptor, and indications when the
///   characteristic supports event notifications.
///
/// - SeeAlso: HAP Specification R2, Sections 7.4.3 – 7.4.4
public enum BLEGATTDatabase {

    /// The Service Instance ID characteristic type (`E604E95D-A759-4817-87D3-AA005083A0D1`).
    ///
    /// - SeeAlso: HAP Specification R2, Section 7.4.4.3 Service Instance ID
    public static let serviceInstanceIDCharacteristicType = HAPUUID(rawValue: UUID(uuid: (
        0xE6, 0x04, 0xE9, 0x5D, 0xA7, 0x59, 0x48, 0x17,
        0x87, 0xD3, 0xAA, 0x00, 0x50, 0x83, 0xA0, 0xD1
    )))

    /// The Characteristic Instance ID descriptor type (`DC46F0FE-81D2-4616-B5D9-6ABDD796939A`).
    ///
    /// - SeeAlso: HAP Specification R2, Section 7.4.4.5.2 Characteristic Instance ID
    public static let characteristicInstanceIDDescriptorType = HAPUUID(rawValue: UUID(uuid: (
        0xDC, 0x46, 0xF0, 0xFE, 0x81, 0xD2, 0x46, 0x16,
        0xB5, 0xD9, 0x6A, 0xBD, 0xD7, 0x96, 0x93, 0x9A
    )))

    /// A GATT characteristic to register for a HAP characteristic.
    public struct CharacteristicEntry: Equatable, Hashable, Sendable {

        /// The characteristic type.
        public let type: HAPUUID

        /// The HAP instance ID.
        public let instanceID: UInt16

        /// The static value of the Characteristic Instance ID descriptor
        /// (the instance ID, 2 bytes little-endian).
        public var instanceIDValue: Data {
            Data(littleEndianBytes(instanceID))
        }

        /// Whether the GATT characteristic supports indications
        /// (connected event notifications).
        public let supportsIndication: Bool
    }

    /// A primary GATT service to register for a HAP service.
    public struct ServiceEntry: Equatable, Hashable, Sendable {

        /// The service type.
        public let type: HAPUUID

        /// The HAP instance ID.
        public let instanceID: UInt16

        /// The static value of the Service Instance ID characteristic
        /// (the instance ID, 2 bytes little-endian).
        public var instanceIDValue: Data {
            Data(littleEndianBytes(instanceID))
        }

        /// The GATT characteristics of the service.
        public let characteristics: [CharacteristicEntry]
    }

    /// The GATT services to register for an accessory's attribute database.
    ///
    /// The accessory must have been validated for Bluetooth LE
    /// (see ``Accessory/validate(transport:)``), which guarantees that all instance IDs
    /// fit in 16 bits.
    public static func services(for accessory: Accessory) -> [ServiceEntry] {
        (accessory.services ?? []).map { service in
            ServiceEntry(
                type: service.serviceType,
                instanceID: UInt16(truncatingIfNeeded: service.iid),
                characteristics: (service.characteristics ?? []).map { characteristic in
                    CharacteristicEntry(
                        type: characteristic.characteristicType,
                        instanceID: UInt16(truncatingIfNeeded: characteristic.iid),
                        supportsIndication: characteristic.properties
                            .contains(.supportsEventNotification)
                    )
                }
            )
        }
    }
}

// MARK: - Bluetooth Serialization

public extension BLEGATTDatabase.ServiceEntry {

    /// The 16-byte little-endian GATT UUID of the service type.
    var bluetoothUUID: Data {
        type.bleData
    }
}

public extension BLEGATTDatabase.CharacteristicEntry {

    /// The 16-byte little-endian GATT UUID of the characteristic type.
    var bluetoothUUID: Data {
        type.bleData
    }
}
