/// Definitions of the services every HAP accessory must expose.
///
/// Instance IDs follow the ADK's conventions: the Accessory Information service occupies
/// instance IDs 1 – 8, the HAP Protocol Information service 0x10 – 0x12, and the Pairing
/// service (required for Bluetooth LE) 0x20 – 0x25. Application services should start
/// at 0x30.
public extension Service {

    /// The Accessory Information service (instance ID 1).
    ///
    /// Contains the accessory's identity characteristics. The hardware revision
    /// characteristic is included only when the accessory declares a hardware version.
    ///
    /// - SeeAlso: HAP Specification R2, Section 8.1 Accessory Information
    static func accessoryInformation(for accessory: Accessory) -> Service {
        var characteristics: [Characteristic] = [
            .bool(BoolCharacteristic(
                iid: 2,
                characteristicType: .identify,
                debugDescription: "identify",
                properties: [.writable]
            )),
            .string(StringCharacteristic(
                iid: 3,
                characteristicType: .manufacturer,
                debugDescription: "manufacturer",
                properties: [.readable],
                maxLength: 64
            )),
            .string(StringCharacteristic(
                iid: 4,
                characteristicType: .model,
                debugDescription: "model",
                properties: [.readable],
                maxLength: 64
            )),
            .string(StringCharacteristic(
                iid: 5,
                characteristicType: .name,
                debugDescription: "name",
                properties: [.readable],
                maxLength: 64
            )),
            .string(StringCharacteristic(
                iid: 6,
                characteristicType: .serialNumber,
                debugDescription: "serial-number",
                properties: [.readable],
                maxLength: 64
            )),
            .string(StringCharacteristic(
                iid: 7,
                characteristicType: .firmwareRevision,
                debugDescription: "firmware-revision",
                properties: [.readable],
                maxLength: 64
            ))
        ]
        if accessory.hardwareVersion != nil {
            characteristics.append(.string(StringCharacteristic(
                iid: 8,
                characteristicType: .hardwareRevision,
                debugDescription: "hardware-revision",
                properties: [.readable],
                maxLength: 64
            )))
        }
        return Service(
            iid: 1,
            serviceType: .accessoryInformation,
            debugDescription: "accessory-information",
            properties: [],
            characteristics: characteristics
        )
    }

    /// The HAP Protocol Information service (instance ID 0x10).
    ///
    /// Carries the protocol version and, on Bluetooth LE, supports the protocol
    /// configuration procedure.
    ///
    /// - SeeAlso: HAP Specification R2, Section 8.17 HAP Protocol Information
    static var hapProtocolInformation: Service {
        Service(
            iid: 0x10,
            serviceType: .hapProtocolInformation,
            debugDescription: "protocol-information",
            properties: [.bleSupportsConfiguration],
            characteristics: [
                .data(DataCharacteristic(
                    iid: 0x11,
                    characteristicType: .serviceSignature,
                    debugDescription: "service-signature",
                    properties: [.readable, .ipControlPoint],
                    maxLength: 2_097_152
                )),
                .string(StringCharacteristic(
                    iid: 0x12,
                    characteristicType: .version,
                    debugDescription: "version",
                    properties: [.readable],
                    maxLength: 64
                ))
            ]
        )
    }

    /// The Pairing service (instance ID 0x20), required for Bluetooth LE accessories.
    ///
    /// The Pair Setup and Pair Verify characteristics are accessible without a secure
    /// session — they carry the pairing exchanges themselves. The pairing management
    /// characteristic requires a secure session.
    ///
    /// - SeeAlso: HAP Specification R2, Section 5.13.1 Pairing Service
    static var pairing: Service {
        Service(
            iid: 0x20,
            serviceType: .pairing,
            debugDescription: "pairing",
            properties: [],
            characteristics: [
                .tlv8(TLV8Characteristic(
                    iid: 0x22,
                    characteristicType: .pairSetup,
                    debugDescription: "pair-setup",
                    properties: [
                        .ipControlPoint,
                        .bleReadableWithoutSecurity, .bleWritableWithoutSecurity
                    ]
                )),
                .tlv8(TLV8Characteristic(
                    iid: 0x23,
                    characteristicType: .pairVerify,
                    debugDescription: "pair-verify",
                    properties: [
                        .ipControlPoint,
                        .bleReadableWithoutSecurity, .bleWritableWithoutSecurity
                    ]
                )),
                .uint8(UInt8Characteristic(
                    iid: 0x24,
                    characteristicType: .pairingFeatures,
                    debugDescription: "pairing-features",
                    properties: [.bleReadableWithoutSecurity],
                    units: .none,
                    minimumValue: 0,
                    maximumValue: .max,
                    stepValue: 0
                )),
                .tlv8(TLV8Characteristic(
                    iid: 0x25,
                    characteristicType: .pairingPairings,
                    debugDescription: "pairing-pairings",
                    properties: [.readable, .writable, .ipControlPoint]
                ))
            ]
        )
    }
}
