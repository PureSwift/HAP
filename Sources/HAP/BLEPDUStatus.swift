/// Status code of a HAP-BLE response PDU.
///
/// - SeeAlso: HAP Specification R2, Table 7-37 HAP Status Codes Description
public enum BLEPDUStatus: UInt8, Equatable, Hashable, Sendable, CaseIterable {

    /// The request was successful.
    case success = 0x00

    /// The PDU or opcode is not supported.
    case unsupportedPDU = 0x01

    /// The accessory has reached the maximum number of simultaneous procedures.
    case maxProcedures = 0x02

    /// The controller is not authorized to perform the operation.
    case insufficientAuthorization = 0x03

    /// The instance ID does not exist.
    case invalidInstanceID = 0x04

    /// A secure session is required to perform the operation.
    case insufficientAuthentication = 0x05

    /// The request is invalid.
    case invalidRequest = 0x06
}
