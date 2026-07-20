/// A write request for a data characteristic.
public struct DataCharacteristicWriteRequest {
    /// Transport type over which the request has been received.
    public var transportType: TransportType

    /// The session over which the request has been received.
    ///
    /// A controller may be logged in on multiple sessions concurrently.
    ///
    /// For remote requests (e.g. via Apple TV), the associated controller may not be the one who originated
    /// the request, but instead the admin controller who set up the Apple TV.
    public var session: Session

    /// The characteristic whose value is to be written.
    public var characteristic: DataCharacteristic

    /// The service that contains the characteristic.
    public var service: Service

    /// The accessory that provides the service.
    public var accessory: Accessory

    /// Whether the request appears to have originated from a remote controller (e.g. via Apple TV).
    public var remote: Bool

    /// Additional authorization data, if provided by the controller.
    public var authorizationData: Data?
}
