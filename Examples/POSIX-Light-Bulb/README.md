# POSIX Light Bulb

A HomeKit colour light bulb over Bluetooth LE, for macOS and Linux.

Companion to [POSIX Smart Lock](../POSIX-Smart-Lock). Where the lock demonstrates timed
writes and a security-sensitive control point, this example demonstrates a **multi-format
attribute database**: a `bool` power state, an `int` percentage, and two `float` values with
different units.

| Characteristic | Format | Unit | Range |
| --- | --- | --- | --- |
| On | `bool` | — | — |
| Brightness | `int` | percentage | 0…100 |
| Hue | `float` | arc degrees | 0…360 |
| Saturation | `float` | percentage | 0…100 |
| Name | `string` | — | ≤ 64 bytes |

Hue and saturation alongside brightness are the representation the Home app's colour picker
drives, so the lamp appears with a full colour wheel.

## Running

```sh
cd Examples
swift run posix-light-bulb --setup-code 518-08-582 --name "Desk Lamp"
```

The accessory persists its identity and pairings under `.posix-light-bulb` in the working
directory, so it stays paired across restarts. Delete that directory to factory reset.

Add it in the Home app with **Add Accessory → More options…** and enter the setup code.
Changing the lamp from the Home app prints the new state:

```
lamp: on · brightness 80% · hue 210° · saturation 45%
```

## Structure

| Piece | File | Role |
| --- | --- | --- |
| Attribute database | [`LightBulb.swift`](LightBulb.swift) | Light Bulb service with colour characteristics |
| Value handling | [`LightBulb.swift`](LightBulb.swift) | `CharacteristicDataSource` holding lamp state |
| Platform abstraction | [`POSIXPlatform.swift`](../POSIXHAP/POSIXPlatform.swift) | Monotonic clock, random source, file-backed key-value store |
| Bluetooth transport | [`Peripheral.swift`](../POSIXHAP/Peripheral.swift) | `HAPPeripheralManager` conformance per platform |
| Wiring | [`main.swift`](main.swift) | Composition and run loop |

The platform and transport pieces live in the shared `POSIXHAP` library, so both examples
share one implementation.

## Platform differences

The same capability caveats apply as for the smart lock — CoreBluetooth cannot broadcast
manufacturer data, so on macOS the accessory is discoverable and controllable but cannot
publish its state in advertisements. See
[the smart lock README](../POSIX-Smart-Lock/README.md#platform-differences) for the details.
