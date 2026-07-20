import Foundation

// MARK: - Requests

/// A read request for a TLV8 characteristic.
public struct TLV8CharacteristicReadRequest {
    /// Transport type over which the response will be sent.
    public var transportType: TransportType

    /// The session over which the response will be sent.
    ///
    /// `nil` when the request is generated internally (e.g. for BLE broadcasts while disconnected).
    public var session: Session?

    /// The characteristic whose value is to be read.
    public var characteristic: TLV8Characteristic

    /// The service that contains the characteristic.
    public var service: Service

    /// The accessory that provides the service.
    public var accessory: Accessory
}

/// A write request for a TLV8 characteristic.
public struct TLV8CharacteristicWriteRequest {
    /// Transport type over which the request has been received.
    public var transportType: TransportType

    /// The session over which the request has been received.
    public var session: Session

    /// The characteristic whose value is to be written.
    public var characteristic: TLV8Characteristic

    /// The service that contains the characteristic.
    public var service: Service

    /// The accessory that provides the service.
    public var accessory: Accessory

    /// Whether the request appears to have originated from a remote controller (e.g. via Apple TV).
    public var remote: Bool

    /// Additional authorization data, if provided by the controller.
    public var authorizationData: Data?
}

/// A subscription (or unsubscription) request for a TLV8 characteristic.
public struct TLV8CharacteristicSubscriptionRequest {
    /// Transport type over which the request has been received.
    public var transportType: TransportType

    /// The session over which the request has been received.
    public var session: Session

    /// The characteristic whose value is to be subscribed or unsubscribed.
    public var characteristic: TLV8Characteristic

    /// The service that contains the characteristic.
    public var service: Service

    /// The accessory that provides the service.
    public var accessory: Accessory
}

// MARK: - Characteristic

/// A HomeKit characteristic that carries one or more TLV8-encoded values.
public struct TLV8Characteristic {
    /// Instance ID.
    public var iid: UInt64

    /// The type of the characteristic.
    public var characteristicType: UUID

    /// Description for debugging (based on the "Type" field of the HAP specification).
    public var debugDescription: String

    /// Description of the characteristic provided by the accessory manufacturer.
    public var manufacturerDescription: String?

    /// Characteristic properties.
    public var properties: CharacteristicProperties

    // MARK: Callbacks

    /// Handles read requests. Must not block.
    ///
    /// Return the raw TLV8-encoded response bytes.
    public var handleRead: ((AccessoryServer, TLV8CharacteristicReadRequest) throws -> Data)?

    /// Handles write requests. Must not block.
    ///
    /// Receives the raw TLV8-encoded request bytes.
    public var handleWrite: ((AccessoryServer, TLV8CharacteristicWriteRequest, Data) throws -> Void)?

    /// Handles subscribe requests. Must not block.
    public var handleSubscribe: ((AccessoryServer, TLV8CharacteristicSubscriptionRequest) -> Void)?

    /// Handles unsubscribe requests. Must not block.
    public var handleUnsubscribe: ((AccessoryServer, TLV8CharacteristicSubscriptionRequest) -> Void)?
}
