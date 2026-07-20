@testable import HAP

/// In-memory BLE configuration state for tests.
struct MockBLEConfigurationContext: BLEConfigurationContext {

    var broadcastConfigurations: [UInt64: BLEBroadcastConfiguration] = [:]

    var globalStateNumber: UInt16 = 1

    var configurationNumber: UInt8 = 1

    var advertisingIdentifier = Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])

    var broadcastKey = Data([UInt8](repeating: 0x5A, count: 32))

    /// When set, all operations fail with this error.
    var failure: HAPError?

    /// Number of times a broadcast encryption key was generated.
    var keyGenerations = 0

    func broadcastConfiguration(
        for characteristic: UInt64
    ) throws(HAPError) -> BLEBroadcastConfiguration {
        if let failure { throw failure }
        return broadcastConfigurations[characteristic] ?? BLEBroadcastConfiguration()
    }

    mutating func setBroadcastConfiguration(
        _ configuration: BLEBroadcastConfiguration,
        for characteristic: UInt64
    ) throws(HAPError) {
        if let failure { throw failure }
        broadcastConfigurations[characteristic] = configuration
    }

    mutating func generateBroadcastEncryptionKey() throws(HAPError) -> Data {
        if let failure { throw failure }
        keyGenerations += 1
        return broadcastKey
    }

    mutating func setAdvertisingIdentifier(_ identifier: Data) throws(HAPError) {
        if let failure { throw failure }
        advertisingIdentifier = identifier
    }
}
