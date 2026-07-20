
/// Properties that HomeKit services can have.
///
/// - Note: ABI-compatible with the C `HAPServiceProperties` struct (`sizeof == 2`).
public struct ServiceProperties: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    /// The service is the primary service on the accessory.
    ///
    /// Only one service may be marked as primary.
    public static let primaryService = Self(rawValue: 1 << 0)

    /// The service should be hidden from the user.
    ///
    /// When all characteristics in a service are marked hidden, the service must also be marked hidden.
    public static let hidden = Self(rawValue: 1 << 1)

    /// The service supports BLE configuration (BLE only).
    ///
    /// Must be set on the HAP Protocol Information service, and must not be set on any other service.
    public static let bleSupportsConfiguration = Self(rawValue: 1 << 2)
}

// MARK: -

/// A request directed at a service.
public struct ServiceRequest {
    /// Transport type over which the request has been received.
    public var transportType: TransportType

    /// The session over which the request has been received.
    public var session: Session

    /// The service that is being accessed.
    public var service: Service

    /// The accessory that provides the service.
    public var accessory: Accessory
}

// MARK: -

/// A HomeKit service.
public struct Service {
    /// Instance ID.
    ///
    /// - Must be unique across all service and characteristic instance IDs of the accessory.
    /// - Must not change while the accessory is paired, including over firmware updates.
    /// - Must be 1 for the Accessory Information Service.
    /// - Must not be 0.
    /// - For accessories that support Bluetooth LE, must not exceed `UInt16.max`.
    public var iid: UInt64

    /// The type of the service.
    public var serviceType: HAPUUID

    /// Description for debugging (based on the "Type" field of the HAP specification).
    public var debugDescription: String

    /// The display name of the service.
    ///
    /// Must be set if the service provides user-visible state or interaction.
    /// Must not be set for invisible services (e.g. a Firmware Update service).
    /// The user may adjust the name on the controller; such changes are local only.
    ///
    /// - Note: Requires a Name characteristic to be attached to the service.
    public var name: String?

    /// Service properties.
    ///
    /// If any properties are set and the accessory supports Bluetooth LE, a Service Signature
    /// characteristic must be attached to the service.
    public var properties: ServiceProperties

    /// Instance IDs of linked services.
    ///
    /// Links are not transitive. Requires a Service Signature characteristic if the accessory supports BLE.
    public var linkedServices: [UInt16]?

    /// The characteristics contained in this service.
    public var characteristics: [Characteristic]?
}
