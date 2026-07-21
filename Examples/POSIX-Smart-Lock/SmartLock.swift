import Foundation
import HAP

/// The lock states of the Lock Mechanism service.
///
/// - SeeAlso: HAP Specification R2, Sections 9.52 Lock Current State and 9.56 Lock Target State
enum LockState: UInt8 {
    case unsecured = 0
    case secured = 1
    case jammed = 2
    case unknown = 3
}

// MARK: - Attribute Database

enum SmartLock {

    /// Instance IDs of the lock's own attributes.
    ///
    /// The standard services occupy the low instance IDs, so the lock starts at `0x30`.
    enum InstanceID {
        static let lockMechanismService: UInt64 = 0x30
        static let lockCurrentState: UInt64 = 0x33
        static let lockTargetState: UInt64 = 0x34
        static let name: UInt64 = 0x35
    }

    /// Builds the lock accessory, including the standard services every accessory must have.
    static func makeAccessory(name: String, serialNumber: String) -> Accessory {
        var accessory = Accessory(
            aid: 1,
            category: .locks,
            name: name,
            manufacturer: "PureSwift",
            model: "SmartLock1,1",
            serialNumber: serialNumber,
            firmwareVersion: "1.0.0"
        )
        accessory.services = [
            .accessoryInformation(for: accessory),
            .hapProtocolInformation,
            .pairing,
            Service(
                iid: InstanceID.lockMechanismService,
                serviceType: .lockMechanism,
                debugDescription: "lock-mechanism",
                properties: [.primaryService],
                characteristics: [
                    // Read-only, with events so the controller learns when the lock moves.
                    .uint8(UInt8Characteristic(
                        iid: InstanceID.lockCurrentState,
                        characteristicType: .lockCurrentState,
                        debugDescription: "lock-current-state",
                        properties: [
                            .readable,
                            .supportsEventNotification,
                            .bleSupportsDisconnectedNotification
                        ],
                        units: .none,
                        minimumValue: LockState.unsecured.rawValue,
                        maximumValue: LockState.unknown.rawValue,
                        stepValue: 1
                    )),
                    // Writable, and a timed write is required: unlocking is a physical
                    // security action, so the controller must confirm intent.
                    .uint8(UInt8Characteristic(
                        iid: InstanceID.lockTargetState,
                        characteristicType: .lockTargetState,
                        debugDescription: "lock-target-state",
                        properties: [
                            .readable,
                            .writable,
                            .supportsEventNotification,
                            .requiresTimedWrite
                        ],
                        units: .none,
                        minimumValue: LockState.unsecured.rawValue,
                        maximumValue: LockState.secured.rawValue,
                        stepValue: 1
                    )),
                    .string(StringCharacteristic(
                        iid: InstanceID.name,
                        characteristicType: .name,
                        debugDescription: "name",
                        properties: [.readable],
                        maxLength: 64
                    ))
                ]
            )
        ]
        return accessory
    }
}

// MARK: - Data Source

/// Serves the lock's characteristic values.
///
/// Applies target-state writes to the mechanism and reflects the result in the current
/// state. A real accessory would drive hardware here and report the state the hardware
/// actually reached.
struct LockDataSource: CharacteristicDataSource {

    /// The lock's display name.
    var name: String

    /// The state the lock is in.
    var currentState: LockState = .secured

    /// The state the controller has asked for.
    var targetState: LockState = .secured

    /// Invoked when the lock changes state, so the server can notify controllers.
    var didChangeState: (@Sendable (LockState) -> Void)?

    func readValue(_ context: CharacteristicReadContext) throws(HAPError) -> CharacteristicValue {
        switch context.characteristic.iid {
        case SmartLock.InstanceID.lockCurrentState:
            return .uint8(currentState.rawValue)
        case SmartLock.InstanceID.lockTargetState:
            return .uint8(targetState.rawValue)
        case SmartLock.InstanceID.name:
            return .string(name)
        default:
            throw .invalidState
        }
    }

    mutating func writeValue(
        _ value: CharacteristicValue,
        _ context: CharacteristicWriteContext
    ) throws(HAPError) {
        guard context.characteristic.iid == SmartLock.InstanceID.lockTargetState,
              case let .uint8(rawValue) = value,
              let target = LockState(rawValue: rawValue)
        else { throw .invalidData }
        targetState = target
        // Drive the mechanism. A real lock would report the state reached by the hardware,
        // including `.jammed` when it fails to move.
        currentState = target
        didChangeState?(target)
    }
}
