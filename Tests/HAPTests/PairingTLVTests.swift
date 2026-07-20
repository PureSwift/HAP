import Testing
@testable import HAP

@Suite
struct PairingTLVTests {

    /// TLV Example 1 from HAP Specification R2, Section 14.1.2 (2 small TLVs).
    @Test
    func example1() throws {
        var tlv = PairingTLV()
        tlv.append(integer: 3, for: .state)  // M3
        tlv.append(string: "hello", for: .identifier)

        let expected: [UInt8] = [
            0x06, 0x01, 0x03,
            0x01, 0x05, 0x68, 0x65, 0x6C, 0x6C, 0x6F
        ]
        #expect(Array(tlv.data) == expected)

        let decoded = try #require(PairingTLV(data: Data(expected)))
        #expect(decoded == tlv)
        #expect(decoded.state == 3)
        #expect(decoded.string(for: .identifier) == "hello")
    }

    /// TLV Example 2 from HAP Specification R2, Section 14.1.2
    /// (1 small TLV, 1 300-byte value split into 2 TLVs, 1 small TLV).
    @Test
    func example2() throws {
        let certificate = Data(repeating: 0x61, count: 300)
        var tlv = PairingTLV()
        tlv.append(integer: 3, for: .state)
        tlv.append(certificate, for: .certificate)
        tlv.append(string: "hello", for: .identifier)

        let data = tlv.data
        #expect(data.count == 314)
        #expect(data[0] == 0x06)    // state
        #expect(data[1] == 0x01)
        #expect(data[2] == 0x03)    // M3
        #expect(data[3] == 0x09)    // certificate
        #expect(data[4] == 0xFF)    // 255 byte fragment
        #expect(data[260] == 0x09)  // certificate continuation
        #expect(data[261] == 0x2D)  // 45 byte fragment
        #expect(data[307] == 0x01)  // identifier
        #expect(data[308] == 0x05)

        let decoded = try #require(PairingTLV(data: data))
        #expect(decoded.items.count == 3)
        #expect(decoded[.certificate] == certificate)
        #expect(decoded.string(for: .identifier) == "hello")
    }

    /// TLV items with unrecognized types must be silently ignored.
    @Test
    func ignoresUnknownTypes() throws {
        let data = Data([
            0x06, 0x01, 0x03,        // state = M3
            0x20, 0x02, 0xAA, 0xBB,  // unknown type 0x20
            0x01, 0x02, 0x68, 0x69   // identifier = "hi"
        ])
        let decoded = try #require(PairingTLV(data: data))
        #expect(decoded.items.count == 2)
        #expect(decoded.state == 3)
        #expect(decoded.string(for: .identifier) == "hi")
    }

    /// Multiple items of the same type are separated by a separator item.
    @Test
    func separator() throws {
        var tlv = PairingTLV()
        tlv.append(string: "one", for: .identifier)
        tlv.appendSeparator()
        tlv.append(string: "two", for: .identifier)

        let decoded = try #require(PairingTLV(data: tlv.data))
        #expect(decoded.items.count == 3)
        #expect(decoded.items[0].value == Data(Array("one".utf8)))
        #expect(decoded.items[1].type == .separator)
        #expect(decoded.items[1].value.isEmpty)
        #expect(decoded.items[2].value == Data(Array("two".utf8)))
    }

    /// A 255-byte value must be contained in a single TLV item; 256 bytes fragments.
    @Test
    func fragmentationBoundary() throws {
        var tlv = PairingTLV()
        tlv.append(Data(repeating: 0x01, count: 255), for: .publicKey)
        #expect(tlv.data.count == 2 + 255)

        var fragmented = PairingTLV()
        fragmented.append(Data(repeating: 0x01, count: 256), for: .publicKey)
        let data = fragmented.data
        #expect(data.count == 2 + 255 + 2 + 1)
        let decoded = try #require(PairingTLV(data: data))
        #expect(decoded.items.count == 1)
        #expect(decoded[.publicKey]?.count == 256)
    }

    /// Integers are little-endian with the minimum number of bytes.
    @Test
    func integers() {
        #expect(Array(PairingTLV.encodeInteger(0)) == [0x00])
        #expect(Array(PairingTLV.encodeInteger(1)) == [0x01])
        #expect(Array(PairingTLV.encodeInteger(300)) == [0x2C, 0x01])
        #expect(Array(PairingTLV.encodeInteger(0x0100_0000)) == [0x00, 0x00, 0x00, 0x01])
        #expect(PairingTLV.decodeInteger(Data([0x2C, 0x01])) == 300)
        #expect(PairingTLV.decodeInteger(Data()) == nil)
        #expect(PairingTLV.decodeInteger(Data(repeating: 0, count: 9)) == nil)
    }

    /// Typed accessors decode method, error, flags, and permissions.
    @Test
    func typedAccessors() throws {
        var tlv = PairingTLV()
        tlv.append(integer: 1, for: .state)
        tlv.append(integer: UInt64(PairingMethod.pairSetupWithAuth.rawValue), for: .method)
        tlv.append(integer: UInt64(PairingFlags.transient.rawValue), for: .flags)
        tlv.append(integer: UInt64(PairingPermissions.admin.rawValue), for: .permissions)
        tlv.append(integer: UInt64(PairingError.backoff.rawValue), for: .error)
        tlv.append(integer: 30, for: .retryDelay)

        let decoded = try #require(PairingTLV(data: tlv.data))
        #expect(decoded.state == 1)
        #expect(decoded.method == .pairSetupWithAuth)
        #expect(decoded.flags == .transient)
        #expect(decoded.permissions == .admin)
        #expect(decoded.error == .backoff)
        #expect(decoded.retryDelay == 30)
    }
}
