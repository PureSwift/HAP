/// Apple-defined HomeKit service types.
///
/// - SeeAlso: HAP Specification R2, Section 8 Apple-defined Services
public extension HAPUUID {

    /// Accessory Information service.
    static let accessoryInformation: HAPUUID = 0x3E

    /// Garage Door Opener service.
    static let garageDoorOpener: HAPUUID = 0x41

    /// Light Bulb service.
    static let lightBulb: HAPUUID = 0x43

    /// Lock Management service.
    static let lockManagement: HAPUUID = 0x44

    /// Lock Mechanism service.
    static let lockMechanism: HAPUUID = 0x45

    /// Outlet service.
    static let outlet: HAPUUID = 0x47

    /// Switch service.
    static let `switch`: HAPUUID = 0x49

    /// Thermostat service.
    static let thermostat: HAPUUID = 0x4A

    /// Pairing service.
    static let pairing: HAPUUID = 0x55

    /// Security System service.
    static let securitySystem: HAPUUID = 0x7E

    /// Carbon Monoxide Sensor service.
    static let carbonMonoxideSensor: HAPUUID = 0x7F

    /// Contact Sensor service.
    static let contactSensor: HAPUUID = 0x80

    /// Door service.
    static let door: HAPUUID = 0x81

    /// Humidity Sensor service.
    static let humiditySensor: HAPUUID = 0x82

    /// Leak Sensor service.
    static let leakSensor: HAPUUID = 0x83

    /// Light Sensor service.
    static let lightSensor: HAPUUID = 0x84

    /// Motion Sensor service.
    static let motionSensor: HAPUUID = 0x85

    /// Occupancy Sensor service.
    static let occupancySensor: HAPUUID = 0x86

    /// Smoke Sensor service.
    static let smokeSensor: HAPUUID = 0x87

    /// Stateless Programmable Switch service.
    static let statelessProgrammableSwitch: HAPUUID = 0x89

    /// Temperature Sensor service.
    static let temperatureSensor: HAPUUID = 0x8A

    /// Window service.
    static let window: HAPUUID = 0x8B

    /// Window Covering service.
    static let windowCovering: HAPUUID = 0x8C

    /// Air Quality Sensor service.
    static let airQualitySensor: HAPUUID = 0x8D

    /// Battery Service service.
    static let batteryService: HAPUUID = 0x96

    /// Carbon Dioxide Sensor service.
    static let carbonDioxideSensor: HAPUUID = 0x97

    /// HAP Protocol Information service.
    static let hapProtocolInformation: HAPUUID = 0xA2

    /// Fan service.
    static let fan: HAPUUID = 0xB7

    /// Fan V2 service.
    static let fanV2: HAPUUID = 0xB7

    /// Slat service.
    static let slat: HAPUUID = 0xB9

    /// Filter Maintenance service.
    static let filterMaintenance: HAPUUID = 0xBA

    /// Air Purifier service.
    static let airPurifier: HAPUUID = 0xBB

    /// Heater Cooler service.
    static let heaterCooler: HAPUUID = 0xBC

    /// Humidifier Dehumidifier service.
    static let humidifierDehumidifier: HAPUUID = 0xBD

    /// Service Label service.
    static let serviceLabel: HAPUUID = 0xCC

    /// Irrigation System service.
    static let irrigationSystem: HAPUUID = 0xCF

    /// Valve service.
    static let valve: HAPUUID = 0xD0

    /// Faucet service.
    static let faucet: HAPUUID = 0xD7

    /// Camera RTP Stream Management service.
    static let cameraRTPStreamManagement: HAPUUID = 0x110

    /// Microphone service.
    static let microphone: HAPUUID = 0x112

    /// Speaker service.
    static let speaker: HAPUUID = 0x113

    /// Doorbell service.
    ///
    /// Primary service of the Video Doorbell Profile.
    static let doorbell: HAPUUID = 0x121

    /// Target Control Management service.
    static let targetControlManagement: HAPUUID = 0x122

    /// Target Control service.
    static let targetControl: HAPUUID = 0x125

    /// Audio Stream Management service.
    static let audioStreamManagement: HAPUUID = 0x127

    /// Data Stream Transport Management service.
    static let dataStreamTransportManagement: HAPUUID = 0x129

    /// Siri service.
    ///
    /// Must be linked to the Audio Stream Management and Data Stream Transport
    /// Management services.
    static let siri: HAPUUID = 0x133
}
