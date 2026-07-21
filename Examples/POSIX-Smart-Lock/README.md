# POSIX Smart Lock

A HomeKit smart lock accessory over Bluetooth LE, for macOS and Linux.

Demonstrates the pieces an application supplies to the `HAP` library:

| Piece | File | Role |
| --- | --- | --- |
| Attribute database | [`SmartLock.swift`](Sources/POSIXSmartLock/SmartLock.swift) | Lock Mechanism service with current/target state |
| Value handling | [`SmartLock.swift`](Sources/POSIXSmartLock/SmartLock.swift) | `CharacteristicDataSource` driving the mechanism |
| Platform abstraction | [`POSIXPlatform.swift`](Sources/POSIXSmartLock/POSIXPlatform.swift) | Monotonic clock, random source, file-backed key-value store |
| Bluetooth transport | [`Peripheral.swift`](Sources/POSIXSmartLock/Peripheral.swift) | `HAPPeripheralManager` conformance per platform |
| Wiring | [`main.swift`](Sources/POSIXSmartLock/main.swift) | Composition and run loop |

## Running

```sh
swift run posix-smart-lock --setup-code 518-08-582 --name "Front Door"
```

The accessory persists its identity and pairings under `.posix-smart-lock` in the working
directory, so it stays paired across restarts. Delete that directory to factory reset.

Add it in the Home app with **Add Accessory → More options…** and enter the setup code.

## Platform differences

The two platforms do not offer the same control over the Bluetooth link layer, and the
accessory reports the difference honestly through
[`HAPPeripheralFeature`](../../Sources/HAP/HAPAdvertisement.swift) rather than pretending:

| Capability | Linux (BlueZ) | macOS (CoreBluetooth) |
| --- | --- | --- |
| Custom manufacturer data | ✅ | ❌ |
| Advertising interval | ✅ | ❌ |
| Disconnect a central | ✅ | ❌ |
| Broadcast events | ✅ | ❌ |

CoreBluetooth peripherals may only advertise a local name and service UUIDs, so on macOS
the accessory advertises its name and the HAP service. Controllers can discover, pair, and
operate the lock, but cannot read the pairing status, global state number, or setup hash
from the advertisement — which means disconnected and broadcast events are unavailable.
The program prints a warning at startup when it detects this.

For a full-fidelity accessory, run on Linux with a Bluetooth controller, or use an
embedded target with direct control of the radio.

## Timed writes

Lock Target State is declared with `.requiresTimedWrite`, so a controller must perform a
timed write followed by an execute write to change it. A plain write is rejected — this is
the specification's protection against a physical security action being triggered by a
stray or replayed request.
