import Testing
@testable import HAP

@Suite
struct HAPUUIDTests {

    @Test
    func appleDefined() {
        let lightBulb = HAPUUID(appleDefined: 0x43)
        #expect(lightBulb.isAppleDefined)
        #expect(lightBulb.appleDefinedValue == 0x43)
        #expect(lightBulb.rawValue.uuidString == "00000043-0000-1000-8000-0026BB765291")
        #expect(lightBulb.description == "43")
    }

    @Test
    func integerLiteral() {
        let accessoryInformation: HAPUUID = 0x3E
        #expect(accessoryInformation == HAPUUID(appleDefined: 0x3E))
        #expect(accessoryInformation.description == "3E")
    }

    @Test
    func shortFormOmitsLeadingZeros() {
        let uuid = HAPUUID(appleDefined: 0x0000_0121)
        #expect(uuid.description == "121")
    }

    @Test
    func vendorSpecific() {
        let uuid = HAPUUID(rawValue: UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!)
        #expect(!uuid.isAppleDefined)
        #expect(uuid.appleDefinedValue == nil)
        #expect(uuid.description == "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
    }
}
