import Dispatch
import Foundation
import GATT
import HAP
import HAPCryptoKit

#if os(Linux)
import BluetoothLinux
#endif

// A HomeKit light bulb over Bluetooth LE, for macOS and Linux.
//
// Usage:
//   posix-light-bulb [--setup-code XXX-XX-XXX] [--name <name>] [--storage <directory>]
//
// The accessory persists its identity and pairings under the storage directory, so it
// stays paired across restarts. Delete that directory to factory reset.

let arguments = CommandLine.arguments

func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: "--\(name)"),
          arguments.index(after: index) < arguments.endIndex
    else { return nil }
    return arguments[arguments.index(after: index)]
}

let name = option("name") ?? "Desk Lamp"
let storageDirectory = URL(
    fileURLWithPath: option("storage") ?? FileManager.default.currentDirectoryPath
        + "/.posix-light-bulb"
)

// The setup code the user enters in the Home app. A production accessory ships with a
// per-unit random code and stores only the SRP verifier — never the code itself.
guard let setupCode = SetupCode(rawValue: option("setup-code") ?? "518-08-582") else {
    print("error: setup code must be formatted XXX-XX-XXX")
    exit(1)
}
guard setupCode.isSecure else {
    print("error: setup code \(setupCode) is trivial and not allowed by the specification")
    exit(1)
}

let crypto = SwiftCryptoProvider()
let store = try FileKeyValueStore(directory: storageDirectory)
let clock = POSIXClock()

// The SRP salt and verifier derived from the setup code. Generated once and persisted, so
// the accessory never keeps the plaintext code.
var random = POSIXRandom()
let setupSalt = random.randomData(count: 16)
let setupVerifier = crypto.srpVerifier(
    username: "Pair-Setup",
    password: setupCode.rawValue,
    salt: setupSalt
)

let accessory = LightBulb.makeAccessory(name: name, serialNumber: "0000000002")
try accessory.validate(transport: .ble)

var lamp = LightBulbDataSource(name: name)
lamp.didChangeState = { state in
    print("lamp: \(state)")
}
let dataSource = StandardDataSource(application: lamp)

let server = try BLEAccessoryServer(
    accessory: accessory,
    crypto: crypto,
    store: store,
    random: random,
    clock: clock,
    dataSource: dataSource,
    setupSalt: setupSalt,
    setupVerifier: setupVerifier
)

#if canImport(Darwin)
let peripheral = NativePeripheral()
#elseif os(Linux)
guard let hostController = await HostController.default else {
    print("error: no Bluetooth controller found")
    exit(1)
}
let peripheral = NativePeripheral(
    hostController: hostController,
    socket: BluetoothLinux.L2CAPSocket.Server.self
)
#endif

let binding = BLEPeripheralServer(peripheral: peripheral, server: server)
binding.didDropConnection = { central in
    print("dropped connection with \(central) after an unrecoverable request")
}

try binding.register()
try peripheral.start()
try binding.updateAdvertising()

if !peripheral.canAdvertiseAccessoryState {
    print("""
        warning: this Bluetooth stack cannot broadcast HAP manufacturer data.
        Controllers can pair and operate the lock, but cannot read the accessory state
        from advertisements, so disconnected and broadcast events are unavailable.
        """)
}

print("""
    \(name) is running.
    Setup code: \(setupCode)
    Storage:    \(storageDirectory.path)
    """)

// Run until interrupted. The HAP core is sans-I/O: the peripheral delivers GATT events on
// its own queue and drives the server through the binding.
dispatchMain()
