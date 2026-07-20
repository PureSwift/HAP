import FoundationEmbedded

/// A HAP-BLE response PDU.
///
/// Wire format: `control (1) ‖ TID (1) ‖ status (1)`, optionally followed by
/// `body length (2, little-endian) ‖ body TLVs`.
///
/// - SeeAlso: HAP Specification R2, Section 7.3.3.3 HAP Response Format
public struct BLEPDUResponse: Equatable, Hashable, Sendable {

    /// Size of the response PDU header in bytes.
    public static let headerSize = 3

    /// The transaction identifier, matching the TID of the request.
    public var transactionID: UInt8

    /// The status code.
    public var status: BLEPDUStatus

    /// The body TLVs, if the PDU has a body.
    public var body: Data?

    public init(
        transactionID: UInt8,
        status: BLEPDUStatus,
        body: Data? = nil
    ) {
        self.transactionID = transactionID
        self.status = status
        self.body = body
    }

    /// Decodes an unfragmented (or reassembled) response PDU.
    public init(data: Data) throws(BLEPDUDecodeError) {
        let bytes = Array(data)
        guard bytes.count >= Self.headerSize else { throw .invalidFormat }
        let control = BLEPDUControlField(rawValue: bytes[0])
        guard control.isValid,
              !control.isContinuation,
              control.pduType == .response,
              let status = BLEPDUStatus(rawValue: bytes[2])
        else { throw .invalidFormat }
        self.transactionID = bytes[1]
        self.status = status
        if bytes.count == Self.headerSize {
            self.body = nil
        } else {
            guard bytes.count >= Self.headerSize + 2 else { throw .invalidFormat }
            let bodyLength = Int(bytes[3]) | Int(bytes[4]) << 8
            guard bytes.count == Self.headerSize + 2 + bodyLength else { throw .invalidFormat }
            self.body = Data(bytes[(Self.headerSize + 2)...])
        }
    }

    /// The encoded, unfragmented PDU.
    public var data: Data {
        var bytes: [UInt8] = [
            BLEPDUControlField.response.rawValue,
            transactionID,
            status.rawValue
        ]
        if let body {
            bytes.append(UInt8(truncatingIfNeeded: body.count))
            bytes.append(UInt8(truncatingIfNeeded: body.count >> 8))
            bytes.append(contentsOf: body)
        }
        return Data(bytes)
    }

    /// The encoded PDU, fragmented to the given maximum fragment size.
    public func fragments(maxFragmentSize: Int) -> [Data] {
        BLEPDUFragmentation.fragments(
            of: data,
            pduType: .response,
            transactionID: transactionID,
            maxFragmentSize: maxFragmentSize
        )
    }
}
