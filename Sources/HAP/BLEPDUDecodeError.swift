/// Errors decoding HAP-BLE PDUs.
public enum BLEPDUDecodeError: Error, Equatable, Hashable, Sendable {

    /// The PDU is malformed (truncated, reserved control bits set, or length mismatch).
    case invalidFormat

    /// The PDU carries an opcode the accessory does not support.
    ///
    /// The accessory shall respond with ``BLEPDUStatus/unsupportedPDU`` using the
    /// transaction ID carried in this error.
    case unsupportedOpcode(transactionID: UInt8)

    /// A continuation fragment was received without a preceding first fragment.
    case unexpectedContinuation

    /// A continuation fragment does not match the transaction of the first fragment.
    case transactionMismatch
}
