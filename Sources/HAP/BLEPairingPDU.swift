import TLVCoding

/// Carriage of pairing TLVs inside HAP-BLE PDU bodies.
///
/// Pairing exchanges — Pair Setup, Pair Verify, and pairing management — travel over
/// Bluetooth LE in the `HAP-Param-Value` parameter of write and read PDUs. Payloads exceed
/// 255 bytes, so the value is fragmented across multiple TLV items which are coalesced here.
///
/// - SeeAlso: HAP Specification R2, Section 5.13 Pairing over Bluetooth LE
public enum BLEPairingPDU {

    /// Extracts the pairing TLV from the `HAP-Param-Value` of a write request body.
    public static func message(from request: BLEPDURequest) -> PairingTLV? {
        guard request.opcode == .characteristicWrite,
              let body = request.body,
              let container = TLVContainer(data: .init(body))
        else { return nil }
        var value = [UInt8]()
        var found = false
        for item in container.items where item.type == BLEPDUParamType.value.typeCode {
            found = true
            value.append(contentsOf: item.value)
        }
        guard found else { return nil }
        return PairingTLV(data: Data(value))
    }

    /// Wraps a pairing response TLV in a response PDU body, fragmenting the value parameter
    /// into 255-byte TLV items.
    public static func response(
        _ message: PairingTLV,
        transactionID: UInt8
    ) -> BLEPDUResponse {
        let value = Array(message.data)
        var body = TLVContainer()
        var offset = 0
        repeat {
            let end = min(offset + 255, value.count)
            body.items.append(TLVItem(
                type: BLEPDUParamType.value.typeCode,
                value: .init(value[offset ..< end])
            ))
            offset = end
        } while offset < value.count
        return BLEPDUResponse(
            transactionID: transactionID,
            status: .success,
            body: Data(body.data)
        )
    }
}
