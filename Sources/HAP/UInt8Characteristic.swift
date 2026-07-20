import FoundationEmbedded

// MARK: - Requests

/// A read request for a UInt8 characteristic.
public struct UInt8CharacteristicReadRequest {
    /// Transport type over which the response will be sent.
    public var transportType: TransportType

    /// The session over which the response will be sent.
    ///
    /// `nil` when the request is generated internally (e.g. for BLE broadcasts while disconnected).
    public var session: Session?

    /// The characteristic whose value is to be read.
    public var characteristic: UInt8Characteristic

    /// The service that contains the characteristic.
    public var service: Service

    /// The accessory that provides the service.
    public var accessory: Accessory
}

/// A write request for a UInt8 characteristic.
public struct UInt8CharacteristicWriteRequest {
    /// Transport type over which the request has been received.
    public var transportType: TransportType

    /// The session over which the request has been received.
    public var session: Session

    /// The characteristic whose value is to be written.
    public var characteristic: UInt8Characteristic

    /// The service that contains the characteristic.
    public var service: Service

    /// The accessory that provides the service.
    public var accessory: Accessory

    /// Whether the request appears to have originated from a remote controller (e.g. via Apple TV).
    public var remote: Bool

    /// Additional authorization data, if provided by the controller.
    public var authorizationData: Data?
}

/// A subscription (or unsubscription) request for a UInt8 characteristic.
public struct UInt8CharacteristicSubscriptionRequest {
    /// Transport type over which the request has been received.
    public var transportType: TransportType

    /// The session over which the request has been received.
    public var session: Session

    /// The characteristic whose value is to be subscribed or unsubscribed.
    public var characteristic: UInt8Characteristic

    /// The service that contains the characteristic.
    public var service: Service

    /// The accessory that provides the service.
    public var accessory: Accessory
}

// MARK: - Characteristic

/// A HomeKit characteristic that carries an unsigned 8-bit integer value.
public struct UInt8Characteristic {
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
    public var minimumValue: UInt8

    /// Maximum value.
    public var maximumValue: UInt8

    /// Step value.
    public var stepValue: UInt8

    /// List of valid values in ascending order. Only supported for Apple-defined characteristics.
    ///
    /// - SeeAlso: HAP Specification R14, Section 7.4.5.3 Valid Values Descriptor
    public var validValues: [UInt8]?

    /// List of valid value ranges in ascending order. Only supported for Apple-defined characteristics.
    ///
    /// - SeeAlso: HAP Specification R14, Section 7.4.5.4 Valid Values Range Descriptor
    public var validValuesRanges: [ClosedRange<UInt8>]?

    // MARK: Callbacks

    /// Handles read requests. Must not block.
    public var handleRead: ((AccessoryServer, UInt8CharacteristicReadRequest) throws -> UInt8)?

    /// Handles write requests. Must not block. Value is pre-validated against constraints.
    public var handleWrite: ((AccessoryServer, UInt8CharacteristicWriteRequest, UInt8) throws -> Void)?

    /// Handles subscribe requests. Must not block.
    public var handleSubscribe: ((AccessoryServer, UInt8CharacteristicSubscriptionRequest) -> Void)?

    /// Handles unsubscribe requests. Must not block.
    public var handleUnsubscribe: ((AccessoryServer, UInt8CharacteristicSubscriptionRequest) -> Void)?
}
