/// Apple-defined HomeKit characteristic types.
///
/// - SeeAlso: HAP Specification R2, Section 9 Apple-defined Characteristics
public extension HAPUUID {

    /// Administrator Only Access characteristic.
    static let administratorOnlyAccess: HAPUUID = 0x1

    /// Audio Feedback characteristic.
    static let audioFeedback: HAPUUID = 0x5

    /// Brightness characteristic.
    static let brightness: HAPUUID = 0x8

    /// Cooling Threshold Temperature characteristic.
    static let coolingThresholdTemperature: HAPUUID = 0xD

    /// Current Door State characteristic.
    static let currentDoorState: HAPUUID = 0xE

    /// Current Heating Cooling State characteristic.
    static let currentHeatingCoolingState: HAPUUID = 0xF

    /// Current Relative Humidity characteristic.
    static let currentRelativeHumidity: HAPUUID = 0x10

    /// Current Temperature characteristic.
    static let currentTemperature: HAPUUID = 0x11

    /// Heating Threshold Temperature characteristic.
    static let heatingThresholdTemperature: HAPUUID = 0x12

    /// Hue characteristic.
    static let hue: HAPUUID = 0x13

    /// Identify characteristic.
    static let identify: HAPUUID = 0x14

    /// Lock Control Point characteristic.
    static let lockControlPoint: HAPUUID = 0x19

    /// Lock Management Auto Security Timeout characteristic.
    static let lockManagementAutoSecurityTimeout: HAPUUID = 0x1A

    /// Lock Last Known Action characteristic.
    static let lockLastKnownAction: HAPUUID = 0x1C

    /// Lock Current State characteristic.
    static let lockCurrentState: HAPUUID = 0x1D

    /// Lock Target State characteristic.
    static let lockTargetState: HAPUUID = 0x1E

    /// Logs characteristic.
    static let logs: HAPUUID = 0x1F

    /// Manufacturer characteristic.
    static let manufacturer: HAPUUID = 0x20

    /// Model characteristic.
    static let model: HAPUUID = 0x21

    /// Motion Detected characteristic.
    static let motionDetected: HAPUUID = 0x22

    /// Name characteristic.
    static let name: HAPUUID = 0x23

    /// Obstruction Detected characteristic.
    static let obstructionDetected: HAPUUID = 0x24

    /// On characteristic.
    static let `on`: HAPUUID = 0x25

    /// Outlet In Use characteristic.
    static let outletInUse: HAPUUID = 0x26

    /// Rotation Direction characteristic.
    static let rotationDirection: HAPUUID = 0x28

    /// Rotation Speed characteristic.
    static let rotationSpeed: HAPUUID = 0x29

    /// Saturation characteristic.
    static let saturation: HAPUUID = 0x2F

    /// Serial Number characteristic.
    static let serialNumber: HAPUUID = 0x30

    /// Target Door State characteristic.
    static let targetDoorState: HAPUUID = 0x32

    /// Target Heating Cooling State characteristic.
    static let targetHeatingCoolingState: HAPUUID = 0x33

    /// Target Relative Humidity characteristic.
    static let targetRelativeHumidity: HAPUUID = 0x34

    /// Target Temperature characteristic.
    static let targetTemperature: HAPUUID = 0x35

    /// Temperature Display Units characteristic.
    static let temperatureDisplayUnits: HAPUUID = 0x36

    /// Version characteristic.
    static let version: HAPUUID = 0x37

    /// Pair Setup characteristic.
    static let pairSetup: HAPUUID = 0x4C

    /// Pair Verify characteristic.
    static let pairVerify: HAPUUID = 0x4E

    /// Pairing Features characteristic.
    static let pairingFeatures: HAPUUID = 0x4F

    /// Pairing Pairings characteristic.
    static let pairingPairings: HAPUUID = 0x50

    /// Firmware Revision characteristic.
    static let firmwareRevision: HAPUUID = 0x52

    /// Hardware Revision characteristic.
    static let hardwareRevision: HAPUUID = 0x53

    /// Air Particulate Density characteristic.
    static let airParticulateDensity: HAPUUID = 0x64

    /// Air Particulate Size characteristic.
    static let airParticulateSize: HAPUUID = 0x65

    /// Security System Current State characteristic.
    static let securitySystemCurrentState: HAPUUID = 0x66

    /// Security System Target State characteristic.
    static let securitySystemTargetState: HAPUUID = 0x67

    /// Battery Level characteristic.
    static let batteryLevel: HAPUUID = 0x68

    /// Carbon Monoxide Detected characteristic.
    static let carbonMonoxideDetected: HAPUUID = 0x69

    /// Contact Sensor State characteristic.
    static let contactSensorState: HAPUUID = 0x6A

    /// Current Ambient Light Level characteristic.
    static let currentAmbientLightLevel: HAPUUID = 0x6B

    /// Current Horizontal Tilt Angle characteristic.
    static let currentHorizontalTiltAngle: HAPUUID = 0x6C

    /// Current Position characteristic.
    static let currentPosition: HAPUUID = 0x6D

    /// Current Vertical Tilt Angle characteristic.
    static let currentVerticalTiltAngle: HAPUUID = 0x6E

    /// Hold Position characteristic.
    static let holdPosition: HAPUUID = 0x6F

    /// Leak Detected characteristic.
    static let leakDetected: HAPUUID = 0x70

    /// Occupancy Detected characteristic.
    static let occupancyDetected: HAPUUID = 0x71

    /// Position State characteristic.
    static let positionState: HAPUUID = 0x72

    /// Programmable Switch Event characteristic.
    static let programmableSwitchEvent: HAPUUID = 0x73

    /// Status Active characteristic.
    static let statusActive: HAPUUID = 0x75

    /// Smoke Detected characteristic.
    static let smokeDetected: HAPUUID = 0x76

    /// Status Fault characteristic.
    static let statusFault: HAPUUID = 0x77

    /// Status Jammed characteristic.
    static let statusJammed: HAPUUID = 0x78

    /// Status Low Battery characteristic.
    static let statusLowBattery: HAPUUID = 0x79

    /// Status Tampered characteristic.
    static let statusTampered: HAPUUID = 0x7A

    /// Target Horizontal Tilt Angle characteristic.
    static let targetHorizontalTiltAngle: HAPUUID = 0x7B

    /// Target Position characteristic.
    static let targetPosition: HAPUUID = 0x7C

    /// Target Vertical Tilt Angle characteristic.
    static let targetVerticalTiltAngle: HAPUUID = 0x7D

    /// Security System Alarm Type characteristic.
    static let securitySystemAlarmType: HAPUUID = 0x8E

    /// Charging State characteristic.
    static let chargingState: HAPUUID = 0x8F

    /// Carbon Monoxide Level characteristic.
    static let carbonMonoxideLevel: HAPUUID = 0x90

    /// Carbon Monoxide Peak Level characteristic.
    static let carbonMonoxidePeakLevel: HAPUUID = 0x91

    /// Carbon Dioxide Detected characteristic.
    static let carbonDioxideDetected: HAPUUID = 0x92

    /// Carbon Dioxide Level characteristic.
    static let carbonDioxideLevel: HAPUUID = 0x93

    /// Carbon Dioxide Peak Level characteristic.
    static let carbonDioxidePeakLevel: HAPUUID = 0x94

    /// Air Quality characteristic.
    static let airQuality: HAPUUID = 0x95

    /// Service Signature characteristic.
    static let serviceSignature: HAPUUID = 0xA5

    /// Accessory Flags characteristic.
    static let accessoryFlags: HAPUUID = 0xA6

    /// Lock Physical Controls characteristic.
    static let lockPhysicalControls: HAPUUID = 0xA7

    /// Target Air Purifier State characteristic.
    static let targetAirPurifierState: HAPUUID = 0xA8

    /// Current Air Purifier State characteristic.
    static let currentAirPurifierState: HAPUUID = 0xA9

    /// Current Slat State characteristic.
    static let currentSlatState: HAPUUID = 0xAA

    /// Filter Life Level characteristic.
    static let filterLifeLevel: HAPUUID = 0xAB

    /// Filter Change Indication characteristic.
    static let filterChangeIndication: HAPUUID = 0xAC

    /// Reset Filter Indication characteristic.
    static let resetFilterIndication: HAPUUID = 0xAD

    /// Current Fan State characteristic.
    static let currentFanState: HAPUUID = 0xAF

    /// Active characteristic.
    static let active: HAPUUID = 0xB0

    /// Current Heater Cooler State characteristic.
    static let currentHeaterCoolerState: HAPUUID = 0xB1

    /// Target Heater Cooler State characteristic.
    static let targetHeaterCoolerState: HAPUUID = 0xB2

    /// Current Humidifier Dehumidifier State characteristic.
    static let currentHumidifierDehumidifierState: HAPUUID = 0xB3

    /// Target Humidifier Dehumidifier State characteristic.
    static let targetHumidifierDehumidifierState: HAPUUID = 0xB4

    /// Water Level characteristic.
    static let waterLevel: HAPUUID = 0xB5

    /// Swing Mode characteristic.
    static let swingMode: HAPUUID = 0xB6

    /// Target Fan State characteristic.
    static let targetFanState: HAPUUID = 0xBF

    /// Slat Type characteristic.
    static let slatType: HAPUUID = 0xC0

    /// Current Tilt Angle characteristic.
    static let currentTiltAngle: HAPUUID = 0xC1

    /// Target Tilt Angle characteristic.
    static let targetTiltAngle: HAPUUID = 0xC2

    /// Ozone Density characteristic.
    static let ozoneDensity: HAPUUID = 0xC3

    /// Nitrogen Dioxide Density characteristic.
    static let nitrogenDioxideDensity: HAPUUID = 0xC4

    /// Sulphur Dioxide Density characteristic.
    static let sulphurDioxideDensity: HAPUUID = 0xC5

    /// PM2.5 Density characteristic.
    static let pm2_5Density: HAPUUID = 0xC6

    /// PM10 Density characteristic.
    static let pm10Density: HAPUUID = 0xC7

    /// VOC Density characteristic.
    static let vocDensity: HAPUUID = 0xC8

    /// Relative Humidity Dehumidifier Threshold characteristic.
    static let relativeHumidityDehumidifierThreshold: HAPUUID = 0xC9

    /// Relative Humidity Humidifier Threshold characteristic.
    static let relativeHumidityHumidifierThreshold: HAPUUID = 0xCA

    /// Service Label Index characteristic.
    static let serviceLabelIndex: HAPUUID = 0xCB

    /// Service Label Namespace characteristic.
    static let serviceLabelNamespace: HAPUUID = 0xCD

    /// Color Temperature characteristic.
    static let colorTemperature: HAPUUID = 0xCE

    /// Program Mode characteristic.
    static let programMode: HAPUUID = 0xD1

    /// In Use characteristic.
    static let inUse: HAPUUID = 0xD2

    /// Set Duration characteristic.
    static let setDuration: HAPUUID = 0xD3

    /// Remaining Duration characteristic.
    static let remainingDuration: HAPUUID = 0xD4

    /// Valve Type characteristic.
    static let valveType: HAPUUID = 0xD5

    /// Is Configured characteristic.
    static let isConfigured: HAPUUID = 0xD6

    /// Active Identifier characteristic.
    static let activeIdentifier: HAPUUID = 0xE7

    /// Supported Video Stream Configuration characteristic.
    static let supportedVideoStreamConfiguration: HAPUUID = 0x114

    /// Supported Audio Stream Configuration characteristic.
    static let supportedAudioStreamConfiguration: HAPUUID = 0x115

    /// Supported RTP Configuration characteristic.
    static let supportedRTPConfiguration: HAPUUID = 0x116

    /// Selected RTP Stream Configuration characteristic.
    static let selectedRTPStreamConfiguration: HAPUUID = 0x117

    /// Setup Endpoints characteristic.
    static let setupEndpoints: HAPUUID = 0x118

    /// Volume characteristic.
    static let volume: HAPUUID = 0x119

    /// Mute characteristic.
    static let mute: HAPUUID = 0x11A

    /// Night Vision characteristic.
    static let nightVision: HAPUUID = 0x11B

    /// Optical Zoom characteristic.
    static let opticalZoom: HAPUUID = 0x11C

    /// Digital Zoom characteristic.
    static let digitalZoom: HAPUUID = 0x11D

    /// Image Rotation characteristic.
    static let imageRotation: HAPUUID = 0x11E

    /// Image Mirroring characteristic.
    static let imageMirroring: HAPUUID = 0x11F

    /// Streaming Status characteristic.
    static let streamingStatus: HAPUUID = 0x120

    /// Target Control Supported Configuration characteristic.
    static let targetControlSupportedConfiguration: HAPUUID = 0x123

    /// Target Control List characteristic.
    static let targetControlList: HAPUUID = 0x124

    /// Button Event characteristic.
    static let buttonEvent: HAPUUID = 0x126

    /// Selected Audio Stream Configuration characteristic.
    static let selectedAudioStreamConfiguration: HAPUUID = 0x128

    /// Supported Data Stream Transport Configuration characteristic.
    static let supportedDataStreamTransportConfiguration: HAPUUID = 0x130

    /// Setup Data Stream Transport characteristic.
    static let setupDataStreamTransport: HAPUUID = 0x131

    /// Siri Input Type characteristic.
    static let siriInputType: HAPUUID = 0x132
}
