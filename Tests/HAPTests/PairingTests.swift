import Testing
@testable import HAP

@Suite
struct PairingTests {

    /// HAP Specification R2, Table 5-3 Methods.
    @Test
    func methods() {
        #expect(PairingMethod.pairSetup.rawValue == 0)
        #expect(PairingMethod.pairSetupWithAuth.rawValue == 1)
        #expect(PairingMethod.pairVerify.rawValue == 2)
        #expect(PairingMethod.addPairing.rawValue == 3)
        #expect(PairingMethod.removePairing.rawValue == 4)
        #expect(PairingMethod.listPairings.rawValue == 5)
    }

    /// HAP Specification R2, Table 5-5 Error Codes.
    @Test
    func errorCodes() {
        #expect(PairingError.unknown.rawValue == 0x01)
        #expect(PairingError.authentication.rawValue == 0x02)
        #expect(PairingError.backoff.rawValue == 0x03)
        #expect(PairingError.maxPeers.rawValue == 0x04)
        #expect(PairingError.maxTries.rawValue == 0x05)
        #expect(PairingError.unavailable.rawValue == 0x06)
        #expect(PairingError.busy.rawValue == 0x07)
    }

    /// HAP Specification R2, Table 5-6 TLV Values.
    @Test
    func tlvTypes() {
        #expect(PairingTLVType.method.rawValue == 0x00)
        #expect(PairingTLVType.identifier.rawValue == 0x01)
        #expect(PairingTLVType.salt.rawValue == 0x02)
        #expect(PairingTLVType.publicKey.rawValue == 0x03)
        #expect(PairingTLVType.proof.rawValue == 0x04)
        #expect(PairingTLVType.encryptedData.rawValue == 0x05)
        #expect(PairingTLVType.state.rawValue == 0x06)
        #expect(PairingTLVType.error.rawValue == 0x07)
        #expect(PairingTLVType.retryDelay.rawValue == 0x08)
        #expect(PairingTLVType.certificate.rawValue == 0x09)
        #expect(PairingTLVType.signature.rawValue == 0x0A)
        #expect(PairingTLVType.permissions.rawValue == 0x0B)
        #expect(PairingTLVType.fragmentData.rawValue == 0x0C)
        #expect(PairingTLVType.fragmentLast.rawValue == 0x0D)
        #expect(PairingTLVType.flags.rawValue == 0x13)
        #expect(PairingTLVType.separator.rawValue == 0xFF)
    }

    /// HAP Specification R2, Table 5-7 Pairing Type Flags.
    @Test
    func flags() {
        #expect(PairingFlags.transient.rawValue == 0x0000_0010)
        #expect(PairingFlags.split.rawValue == 0x0100_0000)
    }

    @Test
    func permissions() {
        #expect(PairingPermissions.admin.rawValue == 0x01)
        #expect(PairingPermissions().rawValue == 0x00)
    }
}
