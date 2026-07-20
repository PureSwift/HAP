/// A characteristic data source that serves the standard services automatically.
///
/// Reads of the Accessory Information characteristics answer from the ``Accessory``
/// definition, the HAP Protocol Information version reports ``protocolVersion``, and
/// Pairing Features reports no authentication features (non-commercial). Everything
/// else — including Identify writes — is forwarded to the application's data source.
public struct StandardDataSource<Application: CharacteristicDataSource>: CharacteristicDataSource {

    /// The application's data source, handling the accessory's own services.
    public var application: Application

    /// The HAP protocol version reported by the HAP Protocol Information service.
    public static var protocolVersion: String { "2.2.0" }

    public init(application: Application) {
        self.application = application
    }

    public func readValue(
        _ context: CharacteristicReadContext
    ) throws(HAPError) -> CharacteristicValue {
        switch (context.service.serviceType, context.characteristic.characteristicType) {
        case (.accessoryInformation, .manufacturer):
            return .string(context.accessory.manufacturer)
        case (.accessoryInformation, .model):
            return .string(context.accessory.model)
        case (.accessoryInformation, .name):
            return .string(context.accessory.name)
        case (.accessoryInformation, .serialNumber):
            return .string(context.accessory.serialNumber)
        case (.accessoryInformation, .firmwareRevision):
            return .string(context.accessory.firmwareVersion)
        case (.accessoryInformation, .hardwareRevision):
            guard let hardwareVersion = context.accessory.hardwareVersion else {
                throw .invalidState
            }
            return .string(hardwareVersion)
        case (.hapProtocolInformation, .version):
            return .string(Self.protocolVersion)
        case (.pairing, .pairingFeatures):
            return .uint8(0)
        default:
            return try application.readValue(context)
        }
    }

    public mutating func writeValue(
        _ value: CharacteristicValue,
        _ context: CharacteristicWriteContext
    ) throws(HAPError) {
        try application.writeValue(value, context)
    }
}
