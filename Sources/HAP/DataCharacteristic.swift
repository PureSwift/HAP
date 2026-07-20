import FoundationEmbedded

/// A HomeKit characteristic that carries an opaque data blob.
public struct DataCharacteristic {
    /// Instance ID.
    ///
    /// - Must be unique across all service and characteristic instance IDs of the accessory.
    /// - Must not change while the accessory is paired, including over firmware updates.
    /// - Must not be 0.
    /// - For accessories that support Bluetooth LE, must not exceed `UInt16.max`.
    public var iid: UInt64

    /// The type of the characteristic.
    public var characteristicType: HAPUUID

    /// Description for debugging (based on the "Type" field of the HAP specification).
    public var debugDescription: String

    /// Description of the characteristic provided by the accessory manufacturer.
    public var manufacturerDescription: String?

    /// Characteristic properties.
    public var properties: CharacteristicProperties

    /// Maximum value length in bytes.
    public var maxLength: UInt32

    // MARK: - Callbacks

    /// Handles read requests.
    ///
    /// Required if ``properties`` includes ``CharacteristicProperties/readable``.
    /// Must not block — prefetch values if the operation would take too long.
    /// The returned `Data` must not exceed ``maxLength`` bytes.
    ///
    /// Throw to signal failure:
    /// - `HAPError.unknown` — unable to perform operation.
    /// - `HAPError.invalidState` — cannot process request in the current state.
    /// - `HAPError.outOfResources` — insufficient resources.
    /// - `HAPError.busy` — request failed temporarily.
    public var handleRead: ((AccessoryServer, DataCharacteristicReadRequest) throws -> Data)?

    /// Handles write requests.
    ///
    /// Required if ``properties`` includes ``CharacteristicProperties/writable``.
    /// Must not block — queue values if the operation would take too long.
    /// The value has already been checked against ``maxLength``.
    ///
    /// Throw to signal failure:
    /// - `HAPError.unknown` — unable to perform operation.
    /// - `HAPError.invalidState` — cannot process request in the current state.
    /// - `HAPError.invalidData` — malformed request from the controller.
    /// - `HAPError.outOfResources` — insufficient resources.
    /// - `HAPError.notAuthorized` — additional authorization data is insufficient.
    /// - `HAPError.busy` — request failed temporarily.
    public var handleWrite: ((AccessoryServer, DataCharacteristicWriteRequest, Data) throws -> Void)?

    /// Handles subscribe requests.
    ///
    /// Must not block — queue work if the operation would take too long.
    public var handleSubscribe: ((AccessoryServer, DataCharacteristicSubscriptionRequest) -> Void)?

    /// Handles unsubscribe requests.
    ///
    /// Must not block — queue work if the operation would take too long.
    public var handleUnsubscribe: ((AccessoryServer, DataCharacteristicSubscriptionRequest) -> Void)?
}
