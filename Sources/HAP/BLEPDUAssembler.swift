
/// Fragmentation of HAP-BLE PDUs.
///
/// Only the control byte and the TID are included in a continuation fragment's PDU header.
/// All fragments have the same PDU type and TID as the first fragment.
///
/// - SeeAlso: HAP Specification R2, Section 7.3.3.5 HAP PDU Fragmentation Scheme
internal enum BLEPDUFragmentation {

    /// Splits an encoded PDU into fragments of at most `maxFragmentSize` bytes.
    static func fragments(
        of pdu: Data,
        pduType: BLEPDUControlField.PDUType,
        transactionID: UInt8,
        maxFragmentSize: Int
    ) -> [Data] {
        precondition(maxFragmentSize > 2)
        guard pdu.count > maxFragmentSize else { return [pdu] }
        let bytes = Array(pdu)
        var fragments = [Data(bytes[0 ..< maxFragmentSize])]
        let continuationHeader: [UInt8] = [
            BLEPDUControlField.continuation(of: pduType).rawValue,
            transactionID
        ]
        var offset = maxFragmentSize
        while offset < bytes.count {
            let end = min(offset + maxFragmentSize - continuationHeader.count, bytes.count)
            fragments.append(Data(continuationHeader + bytes[offset ..< end]))
            offset = end
        }
        return fragments
    }
}

// MARK: -

/// Reassembles fragmented HAP-BLE request PDUs received from a controller.
///
/// The first fragment must contain the complete PDU header and the body length when the
/// optional PDU body is present.
public struct BLEPDUAssembler: Equatable, Hashable, Sendable {

    private var buffer: [UInt8] = []
    private var expectedLength = 0
    private var transactionID: UInt8 = 0
    private var pduTypeBits: UInt8 = 0

    public init() {}

    /// Whether a fragmented PDU is partially assembled.
    public var isAssembling: Bool {
        !buffer.isEmpty
    }

    /// Appends a fragment.
    ///
    /// - Returns: The complete reassembled PDU once the final fragment arrives, `nil` while
    ///   more fragments are expected.
    public mutating func append(_ fragment: Data) throws(BLEPDUDecodeError) -> Data? {
        let bytes = Array(fragment)
        guard !bytes.isEmpty else { throw .invalidFormat }
        let control = BLEPDUControlField(rawValue: bytes[0])
        if buffer.isEmpty {
            guard !control.isContinuation else { throw .unexpectedContinuation }
            // The first fragment must contain the complete header, and the body length
            // field when a body is present.
            switch bytes.count {
            case BLEPDURequest.headerSize:
                expectedLength = BLEPDURequest.headerSize
            case (BLEPDURequest.headerSize + 2)...:
                let bodyLength = Int(bytes[5]) | Int(bytes[6]) << 8
                expectedLength = BLEPDURequest.headerSize + 2 + bodyLength
            default:
                throw .invalidFormat
            }
            transactionID = bytes[2]
            pduTypeBits = control.rawValue & 0b0000_1110
            buffer = bytes
        } else {
            guard control.isContinuation else { throw .invalidFormat }
            guard bytes.count >= 2,
                  control.rawValue & 0b0000_1110 == pduTypeBits,
                  bytes[1] == transactionID
            else {
                reset()
                throw .transactionMismatch
            }
            buffer.append(contentsOf: bytes[2...])
        }
        guard buffer.count <= expectedLength else {
            reset()
            throw .invalidFormat
        }
        if buffer.count == expectedLength {
            let pdu = Data(buffer)
            reset()
            return pdu
        }
        return nil
    }

    /// Discards any partially assembled PDU.
    public mutating func reset() {
        buffer = []
        expectedLength = 0
        transactionID = 0
        pduTypeBits = 0
    }
}
