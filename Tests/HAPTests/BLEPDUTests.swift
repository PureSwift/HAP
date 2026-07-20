import Testing
import FoundationEmbedded
@testable import HAP

@Suite
struct BLEPDUTests {

    // MARK: Control Field

    @Test
    func controlField() {
        #expect(BLEPDUControlField.request.rawValue == 0b0000_0000)
        #expect(BLEPDUControlField.response.rawValue == 0b0000_0010)
        #expect(BLEPDUControlField.continuation(of: .request).rawValue == 0b1000_0000)
        #expect(BLEPDUControlField.continuation(of: .response).rawValue == 0b1000_0010)
        #expect(BLEPDUControlField.request.pduType == .request)
        #expect(BLEPDUControlField.response.pduType == .response)
        #expect(!BLEPDUControlField.request.isContinuation)
        #expect(BLEPDUControlField.continuation(of: .request).isContinuation)
        #expect(BLEPDUControlField(rawValue: 0b0001_0000).usesExtendedInstanceIDs)
        // Reserved bits (5, 6, 0) must be zero.
        #expect(!BLEPDUControlField(rawValue: 0b0100_0000).isValid)
        #expect(!BLEPDUControlField(rawValue: 0b0000_0001).isValid)
        #expect(BLEPDUControlField.request.isValid)
    }

    // MARK: Requests

    /// HAP-Characteristic-Signature-Read-Request (Table 7-12): header only.
    @Test
    func signatureReadRequest() throws {
        let request = BLEPDURequest(
            opcode: .characteristicSignatureRead,
            transactionID: 0x3A,
            instanceID: 0x0022
        )
        #expect(Array(request.data) == [0x00, 0x01, 0x3A, 0x22, 0x00])
        let decoded = try BLEPDURequest(data: request.data)
        #expect(decoded == request)
        #expect(decoded.body == nil)
    }

    /// HAP-Characteristic-Write-Request (Table 7-17): header + body.
    @Test
    func writeRequest() throws {
        let body = Data([0x01, 0x01, 0x42])  // HAP-Param-Value TLV
        let request = BLEPDURequest(
            opcode: .characteristicWrite,
            transactionID: 0x5C,
            instanceID: 0x0105,
            body: body
        )
        #expect(Array(request.data) == [0x00, 0x02, 0x5C, 0x05, 0x01, 0x03, 0x00, 0x01, 0x01, 0x42])
        let decoded = try BLEPDURequest(data: request.data)
        #expect(decoded == request)
        #expect(decoded.body == body)
    }

    @Test
    func requestDecodeRejectsMalformed() {
        // Truncated header.
        #expect(throws: BLEPDUDecodeError.invalidFormat) {
            try BLEPDURequest(data: Data([0x00, 0x01, 0x3A]))
        }
        // Body length mismatch.
        #expect(throws: BLEPDUDecodeError.invalidFormat) {
            try BLEPDURequest(data: Data([0x00, 0x02, 0x3A, 0x22, 0x00, 0x05, 0x00, 0x01]))
        }
        // 64-bit instance IDs are not supported.
        #expect(throws: BLEPDUDecodeError.invalidFormat) {
            try BLEPDURequest(data: Data([0x10, 0x01, 0x3A, 0x22, 0x00]))
        }
        // Unknown opcode reports the transaction ID for the error response.
        #expect(throws: BLEPDUDecodeError.unsupportedOpcode(transactionID: 0x3A)) {
            try BLEPDURequest(data: Data([0x00, 0xEE, 0x3A, 0x22, 0x00]))
        }
    }

    // MARK: Responses

    /// HAP-Characteristic-Write-Response (Table 7-18): header only.
    @Test
    func writeResponse() throws {
        let response = BLEPDUResponse(transactionID: 0x5C, status: .success)
        #expect(Array(response.data) == [0x02, 0x5C, 0x00])
        let decoded = try BLEPDUResponse(data: response.data)
        #expect(decoded == response)
    }

    /// HAP-Characteristic-Read-Response (Table 7-20): header + body.
    @Test
    func readResponse() throws {
        let body = Data([0x01, 0x01, 0x2A])
        let response = BLEPDUResponse(transactionID: 0x11, status: .success, body: body)
        #expect(Array(response.data) == [0x02, 0x11, 0x00, 0x03, 0x00, 0x01, 0x01, 0x2A])
        let decoded = try BLEPDUResponse(data: response.data)
        #expect(decoded == response)
    }

    @Test
    func errorResponse() throws {
        let response = BLEPDUResponse(transactionID: 0x07, status: .invalidInstanceID)
        #expect(Array(response.data) == [0x02, 0x07, 0x04])
    }

    // MARK: Fragmentation

    @Test
    func unfragmentedWhenFitting() {
        let request = BLEPDURequest(
            opcode: .characteristicRead,
            transactionID: 0x01,
            instanceID: 5
        )
        #expect(request.fragments(maxFragmentSize: 23) == [request.data])
    }

    @Test
    func fragmentationRoundtrip() throws {
        let body = Data((0 ..< 200).map { UInt8(truncatingIfNeeded: $0) })
        let request = BLEPDURequest(
            opcode: .characteristicWrite,
            transactionID: 0x9D,
            instanceID: 0x0042,
            body: body
        )
        let fragments = request.fragments(maxFragmentSize: 23)
        #expect(fragments.count > 1)
        #expect(fragments.allSatisfy { $0.count <= 23 })
        // First fragment starts with the request control field, continuations with
        // the continuation control field and the same TID.
        #expect(fragments[0][0] == 0b0000_0000)
        for continuation in fragments.dropFirst() {
            #expect(continuation[0] == 0b1000_0000)
            #expect(continuation[1] == 0x9D)
        }

        var assembler = BLEPDUAssembler()
        var assembled: Data?
        for fragment in fragments {
            #expect(assembled == nil)
            assembled = try assembler.append(fragment)
        }
        let pdu = try #require(assembled)
        let decoded = try BLEPDURequest(data: pdu)
        #expect(decoded == request)
        #expect(!assembler.isAssembling)
    }

    @Test
    func responseFragmentation() throws {
        let body = Data([UInt8](repeating: 0xAB, count: 100))
        let response = BLEPDUResponse(transactionID: 0x33, status: .success, body: body)
        let fragments = response.fragments(maxFragmentSize: 27)
        #expect(fragments.count > 1)
        #expect(fragments[0][0] == 0b0000_0010)
        for continuation in fragments.dropFirst() {
            #expect(continuation[0] == 0b1000_0010)
            #expect(continuation[1] == 0x33)
        }
        // Reassemble by stripping continuation headers.
        var reassembled = Array(fragments[0])
        for continuation in fragments.dropFirst() {
            reassembled.append(contentsOf: Array(continuation).dropFirst(2))
        }
        let decoded = try BLEPDUResponse(data: Data(reassembled))
        #expect(decoded == response)
    }

    // MARK: Assembler Errors

    @Test
    func assemblerRejectsUnexpectedContinuation() {
        var assembler = BLEPDUAssembler()
        #expect(throws: BLEPDUDecodeError.unexpectedContinuation) {
            try assembler.append(Data([0b1000_0000, 0x01, 0xFF]))
        }
    }

    @Test
    func assemblerRejectsTransactionMismatch() throws {
        let request = BLEPDURequest(
            opcode: .characteristicWrite,
            transactionID: 0x10,
            instanceID: 1,
            body: Data([UInt8](repeating: 0, count: 50))
        )
        let fragments = request.fragments(maxFragmentSize: 23)
        var assembler = BLEPDUAssembler()
        _ = try assembler.append(fragments[0])
        var wrongTID = Array(fragments[1])
        wrongTID[1] = 0x99
        #expect(throws: BLEPDUDecodeError.transactionMismatch) {
            try assembler.append(Data(wrongTID))
        }
        #expect(!assembler.isAssembling)  // mismatch discards the partial PDU
    }

    @Test
    func assemblerHandlesHeaderOnlyRequest() throws {
        var assembler = BLEPDUAssembler()
        let pdu = try #require(try assembler.append(Data([0x00, 0x03, 0x2B, 0x07, 0x00])))
        let request = try BLEPDURequest(data: pdu)
        #expect(request.opcode == .characteristicRead)
        #expect(request.transactionID == 0x2B)
        #expect(request.instanceID == 7)
    }
}
