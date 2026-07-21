import Foundation
import HAP

// MARK: - Attribute Database

enum LightBulb {

    /// Instance IDs of the light bulb's own attributes.
    ///
    /// The standard services occupy the low instance IDs, so the bulb starts at `0x30`.
    enum InstanceID {
        static let lightBulbService: UInt64 = 0x30
        static let on: UInt64 = 0x33
        static let brightness: UInt64 = 0x34
        static let hue: UInt64 = 0x35
        static let saturation: UInt64 = 0x36
        static let name: UInt64 = 0x37
    }

    /// Builds a color light bulb, including the standard services every accessory must have.
    ///
    /// Colour is expressed as hue and saturation alongside brightness — the representation
    /// the Home app's colour picker uses.
    ///
    /// - SeeAlso: HAP Specification R2, Section 8.23 Light Bulb
    static func makeAccessory(name: String, serialNumber: String) -> Accessory {
        var accessory = Accessory(
            aid: 1,
            category: .lighting,
            name: name,
            manufacturer: "PureSwift",
            model: "LightBulb1,1",
            serialNumber: serialNumber,
            firmwareVersion: "1.0.0"
        )
        accessory.services = [
            .accessoryInformation(for: accessory),
            .hapProtocolInformation,
            .pairing,
            Service(
                iid: InstanceID.lightBulbService,
                serviceType: .lightBulb,
                debugDescription: "light-bulb",
                properties: [.primaryService],
                characteristics: [
                    // The only required characteristic of the service.
                    .bool(BoolCharacteristic(
                        iid: InstanceID.on,
                        characteristicType: .on,
                        debugDescription: "on",
                        properties: [
                            .readable,
                            .writable,
                            .supportsEventNotification,
                            .bleSupportsDisconnectedNotification
                        ]
                    )),
                    // Brightness is a signed integer percentage.
                    .int(IntCharacteristic(
                        iid: InstanceID.brightness,
                        characteristicType: .brightness,
                        debugDescription: "brightness",
                        properties: [.readable, .writable, .supportsEventNotification],
                        units: .percentage,
                        minimumValue: 0,
                        maximumValue: 100,
                        stepValue: 1
                    )),
                    // Hue is a float in arc degrees around the colour wheel.
                    .float(FloatCharacteristic(
                        iid: InstanceID.hue,
                        characteristicType: .hue,
                        debugDescription: "hue",
                        properties: [.readable, .writable, .supportsEventNotification],
                        units: .arcDegrees,
                        minimumValue: 0,
                        maximumValue: 360,
                        stepValue: 1
                    )),
                    .float(FloatCharacteristic(
                        iid: InstanceID.saturation,
                        characteristicType: .saturation,
                        debugDescription: "saturation",
                        properties: [.readable, .writable, .supportsEventNotification],
                        units: .percentage,
                        minimumValue: 0,
                        maximumValue: 100,
                        stepValue: 1
                    )),
                    .string(StringCharacteristic(
                        iid: InstanceID.name,
                        characteristicType: .name,
                        debugDescription: "name",
                        properties: [.readable],
                        maxLength: 64
                    ))
                ]
            )
        ]
        return accessory
    }
}

// MARK: - Data Source

/// Serves the light bulb's characteristic values.
///
/// Holds the lamp state in memory and prints it on every change. A real accessory would
/// drive an LED driver here and report the state the hardware actually reached.
struct LightBulbDataSource: CharacteristicDataSource {

    /// The bulb's display name.
    var name: String

    /// Whether the lamp is lit.
    var isOn = false

    /// Brightness as a percentage.
    var brightness: Int32 = 100

    /// Hue in arc degrees.
    var hue: Float = 0

    /// Saturation as a percentage.
    var saturation: Float = 0

    /// Invoked whenever the lamp state changes, so the server can notify controllers.
    var didChangeState: (@Sendable (LightBulbDataSource) -> Void)?

    func readValue(_ context: CharacteristicReadContext) throws(HAPError) -> CharacteristicValue {
        switch context.characteristic.iid {
        case LightBulb.InstanceID.on:
            return .bool(isOn)
        case LightBulb.InstanceID.brightness:
            return .int(brightness)
        case LightBulb.InstanceID.hue:
            return .float(hue)
        case LightBulb.InstanceID.saturation:
            return .float(saturation)
        case LightBulb.InstanceID.name:
            return .string(name)
        default:
            throw .invalidState
        }
    }

    mutating func writeValue(
        _ value: CharacteristicValue,
        _ context: CharacteristicWriteContext
    ) throws(HAPError) {
        // The value has already been validated against the characteristic's format and
        // constraints, so a mismatch here means the database and this switch disagree.
        switch (context.characteristic.iid, value) {
        case let (LightBulb.InstanceID.on, .bool(newValue)):
            isOn = newValue
        case let (LightBulb.InstanceID.brightness, .int(newValue)):
            brightness = newValue
        case let (LightBulb.InstanceID.hue, .float(newValue)):
            hue = newValue
        case let (LightBulb.InstanceID.saturation, .float(newValue)):
            saturation = newValue
        default:
            throw .invalidData
        }
        didChangeState?(self)
    }
}

extension LightBulbDataSource: CustomStringConvertible {

    var description: String {
        isOn
            ? "on · brightness \(brightness)% · hue \(Int(hue))° · saturation \(Int(saturation))%"
            : "off"
    }
}
