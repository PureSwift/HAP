
// MARK: - Requests

/// A read request for a UInt16 characteristic.
public struct UInt16CharacteristicReadRequest {
    /// Transport type over which the response will be sent.
    public var transportType: TransportType

    /// The session over which the response will be sent.
    ///
    /// `nil` when the request is generated internally (e.g. for BLE broadcasts while disconnected).
    public var session: Session?

    /// The characteristic whose value is to be read.
    public var characteristic: UInt16Characteristic

    /// The service that contains the characteristic.
    public var service: Service

    /// The accessory that provides the service.
    public var accessory: Accessory
}

/// A write request for a UInt16 characteristic.
public struct UInt16CharacteristicWriteRequest {
    /// Transport type over which the request has been received.
    public var transportType: TransportType

    /// The session over which the request has been received.
    public var session: Session

    /// The characteristic whose value is to be written.
    public var characteristic: UInt16Characteristic

    /// The service that contains the characteristic.
    public var service: Service

    /// The accessory that provides the service.
    public var accessory: Accessory

    /// Whether the request appears to have originated from a remote controller (e.g. via Apple TV).
    public var remote: Bool

    /// Additional authorization data, if provided by the controller.
    public var authorizationData: Data?
}

/// A subscription (or unsubscription) request for a UInt16 characteristic.
public struct UInt16CharacteristicSubscriptionRequest {
    /// Transport type over which the request has been received.
    public var transportType: TransportType

    /// The session over which the request has been received.
    public var session: Session

    /// The characteristic whose value is to be subscribed or unsubscribed.
    public var characteristic: UInt16Characteristic

    /// The service that contains the characteristic.
    public var service: Service

    /// The accessory that provides the service.
    public var accessory: Accessory
}

// MARK: - Characteristic

/// A HomeKit characteristic that carries an unsigned 16-bit integer value.
public struct UInt16Characteristic {

    /// Creates a characteristic.
    public init(
        iid: UInt64,
        characteristicType: HAPUUID,
        debugDescription: String,
        manufacturerDescription: String? = nil,
        properties: CharacteristicProperties,
        units: CharacteristicUnits,
        minimumValue: UInt16,
        maximumValue: UInt16,
        stepValue: UInt16
    ) {
        self.iid = iid
        self.characteristicType = characteristicType
        self.debugDescription = debugDescription
        self.manufacturerDescription = manufacturerDescription
        self.properties = properties
        self.units = units
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.stepValue = stepValue
    }

    /// Instance ID.
    public var iid: UInt64

    /// The type of the characteristic.
    public var characteristicType: HAPUUID

    /// Description for debugging (based on the "Type" field of the HAP specification).
    public var debugDescription: String

    /// Description of the characteristic provided by the accessory manufacturer.
    public var manufacturerDescription: String?

    /// Characteristic properties.
    public var properties: CharacteristicProperties

    /// The units of the characteristic's values.
    public var units: CharacteristicUnits

    // MARK: Constraints

    /// Minimum value.
    public var minimumValue: UInt16

    /// Maximum value.
    public var maximumValue: UInt16

    /// Step value.
    public var stepValue: UInt16

    // MARK: Callbacks

    /// Handles read requests. Must not block.
    public var handleRead: ((AccessoryServer, UInt16CharacteristicReadRequest) throws -> UInt16)?

    /// Handles write requests. Must not block. Value is pre-validated against constraints.
    public var handleWrite: ((AccessoryServer, UInt16CharacteristicWriteRequest, UInt16) throws -> Void)?

    /// Handles subscribe requests. Must not block.
    public var handleSubscribe: ((AccessoryServer, UInt16CharacteristicSubscriptionRequest) -> Void)?

    /// Handles unsubscribe requests. Must not block.
    public var handleUnsubscribe: ((AccessoryServer, UInt16CharacteristicSubscriptionRequest) -> Void)?
}
