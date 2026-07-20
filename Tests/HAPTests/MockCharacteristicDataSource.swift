@testable import HAP

/// In-memory characteristic value store for tests.
struct MockCharacteristicDataSource: CharacteristicDataSource {

    /// Current values by characteristic instance ID.
    var values: [UInt64: CharacteristicValue] = [:]

    /// Values written, in order, with their contexts.
    var writes: [(value: CharacteristicValue, context: CharacteristicWriteContext)] = []

    /// When set, reads fail with this error.
    var readFailure: HAPError?

    /// When set, writes fail with this error.
    var writeFailure: HAPError?

    func readValue(_ context: CharacteristicReadContext) throws(HAPError) -> CharacteristicValue {
        if let readFailure { throw readFailure }
        guard let value = values[context.characteristic.iid] else {
            throw HAPError.invalidState
        }
        return value
    }

    mutating func writeValue(
        _ value: CharacteristicValue,
        _ context: CharacteristicWriteContext
    ) throws(HAPError) {
        if let writeFailure { throw writeFailure }
        values[context.characteristic.iid] = value
        writes.append((value, context))
    }
}
