/// Errors detected while validating an accessory's attribute database.
///
/// - SeeAlso: HAP Specification R2, Section 2.6 Accessory Attribute Database
public enum AccessoryValidationError: Error, Equatable, Hashable, Sendable {

    /// The accessory instance ID is invalid (must not be 0; must be 1 for regular accessories).
    case invalidAccessoryInstanceID(UInt64)

    /// The accessory does not define any services.
    case missingServices

    /// The accessory does not contain the Accessory Information service.
    case missingAccessoryInformationService

    /// The Accessory Information service must have instance ID 1.
    case invalidAccessoryInformationServiceInstanceID(UInt64)

    /// A service or characteristic instance ID is 0.
    case zeroInstanceID

    /// A service or characteristic instance ID is used more than once.
    case duplicateInstanceID(UInt64)

    /// An instance ID exceeds `UInt16.max`, which is not allowed for accessories
    /// that support Bluetooth LE.
    case instanceIDExceedsBluetoothLimit(UInt64)

    /// A linked service references an instance ID that is not a service of the accessory.
    case invalidLinkedService(UInt16)
}

// MARK: -

public extension Accessory {

    /// Validates the accessory's attribute database.
    ///
    /// Checks the instance ID rules of the specification:
    /// - Instance IDs must not be 0 and must be unique across all services and
    ///   characteristics of the accessory.
    /// - The Accessory Information service must be present with instance ID 1.
    /// - For accessories that support Bluetooth LE, instance IDs must not exceed `UInt16.max`.
    /// - Linked services must reference services of the accessory, and a service
    ///   must not link to itself.
    ///
    /// - Parameter transport: Restricts validation to transport-specific rules,
    ///   or `nil` to validate the strictest (Bluetooth LE) rules.
    ///
    /// - SeeAlso: HAP Specification R2, Section 2.6 Accessory Attribute Database
    func validate(transport: TransportType? = nil) throws(AccessoryValidationError) {
        guard aid != 0 else {
            throw .invalidAccessoryInstanceID(aid)
        }
        guard let services, !services.isEmpty else {
            throw .missingServices
        }
        guard let accessoryInformation = services.first(where: { $0.serviceType == .accessoryInformation }) else {
            throw .missingAccessoryInformationService
        }
        guard accessoryInformation.iid == 1 else {
            throw .invalidAccessoryInformationServiceInstanceID(accessoryInformation.iid)
        }
        let enforceBluetoothLimit = transport != .ip
        var usedInstanceIDs = Set<UInt64>()
        var serviceInstanceIDs = Set<UInt64>()
        for service in services {
            try Self.validate(
                instanceID: service.iid,
                in: &usedInstanceIDs,
                enforceBluetoothLimit: enforceBluetoothLimit
            )
            serviceInstanceIDs.insert(service.iid)
            for characteristic in service.characteristics ?? [] {
                try Self.validate(
                    instanceID: characteristic.iid,
                    in: &usedInstanceIDs,
                    enforceBluetoothLimit: enforceBluetoothLimit
                )
            }
        }
        for service in services {
            for linkedService in service.linkedServices ?? [] {
                guard UInt64(linkedService) != service.iid,
                      serviceInstanceIDs.contains(UInt64(linkedService))
                else { throw .invalidLinkedService(linkedService) }
            }
        }
    }
}

private extension Accessory {

    static func validate(
        instanceID: UInt64,
        in usedInstanceIDs: inout Set<UInt64>,
        enforceBluetoothLimit: Bool
    ) throws(AccessoryValidationError) {
        guard instanceID != 0 else {
            throw .zeroInstanceID
        }
        guard usedInstanceIDs.insert(instanceID).inserted else {
            throw .duplicateInstanceID(instanceID)
        }
        if enforceBluetoothLimit, instanceID > UInt64(UInt16.max) {
            throw .instanceIDExceedsBluetoothLimit(instanceID)
        }
    }
}
