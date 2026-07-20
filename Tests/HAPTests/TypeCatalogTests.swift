import Testing
@testable import HAP

@Suite
struct TypeCatalogTests {

    /// Spot checks against HAP Specification R2, Section 8 Apple-defined Services.
    @Test
    func serviceTypes() {
        #expect(HAPUUID.accessoryInformation == 0x3E)
        #expect(HAPUUID.lightBulb == 0x43)
        #expect(HAPUUID.`switch` == 0x49)
        #expect(HAPUUID.thermostat == 0x4A)
        #expect(HAPUUID.hapProtocolInformation == 0xA2)
        #expect(HAPUUID.doorbell == 0x121)
        #expect(HAPUUID.accessoryInformation.description == "3E")
        #expect(HAPUUID.lightBulb.rawValue.uuidString == "00000043-0000-1000-8000-0026BB765291")
    }

    /// Spot checks against HAP Specification R2, Section 9 Apple-defined Characteristics.
    @Test
    func characteristicTypes() {
        #expect(HAPUUID.on == 0x25)
        #expect(HAPUUID.brightness == 0x8)
        #expect(HAPUUID.hue == 0x13)
        #expect(HAPUUID.saturation == 0x2F)
        #expect(HAPUUID.currentTemperature == 0x11)
        #expect(HAPUUID.name == 0x23)
        #expect(HAPUUID.identify == 0x14)
        #expect(HAPUUID.serialNumber == 0x30)
        #expect(HAPUUID.firmwareRevision == 0x52)
        #expect(HAPUUID.version == 0x37)
        #expect(HAPUUID.brightness.description == "8")
    }
}
