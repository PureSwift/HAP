/// The transport over which a HAP session operates.
public enum TransportType: UInt8 {
    /// HAP over IP (Ethernet / Wi-Fi).
    case ip = 1

    /// HAP over Bluetooth LE.
    case ble = 2
}
