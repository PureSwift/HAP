/// A read request for a data characteristic.
public struct DataCharacteristicReadRequest {
    /// Transport type over which the response will be sent.
    public var transportType: TransportType

    /// The session over which the response will be sent.
    ///
    /// A controller may be logged in on multiple sessions concurrently.
    /// `nil` when the request is generated internally (e.g. for BLE broadcasts while disconnected).
    ///
    /// For remote requests (e.g. via Apple TV), the associated controller may not be the one who originated
    /// the request, but instead the admin controller who set up the Apple TV.
    public var session: Session?

    /// The characteristic whose value is to be read.
    public var characteristic: DataCharacteristic

    /// The service that contains the characteristic.
    public var service: Service

    /// The accessory that provides the service.
    public var accessory: Accessory
}
