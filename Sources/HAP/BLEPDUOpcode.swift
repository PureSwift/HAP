/// HAP opcode of a HAP-BLE request PDU.
///
/// If an accessory receives a HAP PDU with an opcode that it does not support, it shall
/// reject the PDU and respond with ``BLEPDUStatus/unsupportedPDU``.
///
/// - SeeAlso: HAP Specification R2, Table 7-8 HAP Opcode Description
public enum BLEPDUOpcode: UInt8, Equatable, Hashable, Sendable, CaseIterable {

    /// HAP-Characteristic-Signature-Read.
    case characteristicSignatureRead = 0x01

    /// HAP-Characteristic-Write.
    case characteristicWrite = 0x02

    /// HAP-Characteristic-Read.
    case characteristicRead = 0x03

    /// HAP-Characteristic-Timed-Write.
    case characteristicTimedWrite = 0x04

    /// HAP-Characteristic-Execute-Write.
    case characteristicExecuteWrite = 0x05

    /// HAP-Service-Signature-Read.
    case serviceSignatureRead = 0x06

    /// HAP-Characteristic-Configuration.
    case characteristicConfiguration = 0x07

    /// HAP-Protocol-Configuration.
    case protocolConfiguration = 0x08
}
