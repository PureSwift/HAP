/// Context of a characteristic read.
public struct CharacteristicReadContext {

    /// Transport type over which the response will be sent.
    public var transportType: TransportType

    /// The characteristic whose value is to be read.
    public var characteristic: Characteristic

    /// The service that contains the characteristic.
    public var service: Service

    /// The accessory that provides the service.
    public var accessory: Accessory

    public init(
        transportType: TransportType,
        characteristic: Characteristic,
        service: Service,
        accessory: Accessory
    ) {
        self.transportType = transportType
        self.characteristic = characteristic
        self.service = service
        self.accessory = accessory
    }
}

// MARK: -

/// Context of a characteristic write.
public struct CharacteristicWriteContext {

    /// Transport type over which the request has been received.
    public var transportType: TransportType

    /// The characteristic whose value is to be written.
    public var characteristic: Characteristic

    /// The service that contains the characteristic.
    public var service: Service

    /// The accessory that provides the service.
    public var accessory: Accessory

    /// Whether the request appears to have originated from a remote controller.
    public var remote: Bool

    /// Additional authorization data, if provided by the controller.
    public var authorizationData: Data?

    public init(
        transportType: TransportType,
        characteristic: Characteristic,
        service: Service,
        accessory: Accessory,
        remote: Bool = false,
        authorizationData: Data? = nil
    ) {
        self.transportType = transportType
        self.characteristic = characteristic
        self.service = service
        self.accessory = accessory
        self.remote = remote
        self.authorizationData = authorizationData
    }
}

// MARK: -

/// Supplies and accepts characteristic values on behalf of the accessory.
///
/// This is the boundary between the transport-agnostic protocol implementation and
/// application code: the transports resolve instance IDs, enforce the protocol rules, and
/// validate values, then read and write through this protocol.
///
/// Implementations must not block — prefetch values that are expensive to obtain, and queue
/// writes that take too long to apply.
public protocol CharacteristicDataSource {

    /// Returns the current value of a characteristic.
    ///
    /// The returned value's format must match the characteristic's format.
    ///
    /// - Throws: ``HAPError/invalidState`` if the value cannot be read in the current state,
    ///   ``HAPError/notAuthorized`` if the controller is not authorized,
    ///   ``HAPError/busy`` if the read failed temporarily.
    func readValue(_ context: CharacteristicReadContext) throws(HAPError) -> CharacteristicValue

    /// Applies a new value to a characteristic.
    ///
    /// The value has already been checked against the characteristic's format and constraints.
    ///
    /// - Throws: ``HAPError/invalidData`` if the request is malformed,
    ///   ``HAPError/invalidState`` if the value cannot be written in the current state,
    ///   ``HAPError/notAuthorized`` if the additional authorization data is insufficient,
    ///   ``HAPError/busy`` if the write failed temporarily.
    mutating func writeValue(
        _ value: CharacteristicValue,
        _ context: CharacteristicWriteContext
    ) throws(HAPError)
}
