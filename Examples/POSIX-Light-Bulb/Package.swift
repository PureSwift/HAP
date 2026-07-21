// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "POSIXLightBulb",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "posix-light-bulb",
            targets: ["POSIXLightBulb"]
        )
    ],
    dependencies: [
        .package(name: "HAP", path: "../.."),
        .package(
            url: "https://github.com/PureSwift/GATT.git",
            from: "4.0.0",
            traits: ["BluetoothGATT"]
        ),
        // BluetoothLinux tracks Bluetooth's master branch, so the example pins both to
        // master until BluetoothLinux ships a release built against Bluetooth 8.
        .package(
            url: "https://github.com/PureSwift/Bluetooth.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/PureSwift/BluetoothLinux.git",
            branch: "master"
        )
    ],
    targets: [
        .executableTarget(
            name: "POSIXLightBulb",
            dependencies: [
                .product(name: "HAP", package: "HAP"),
                .product(name: "HAPCryptoKit", package: "HAP"),
                .product(name: "GATT", package: "GATT"),
                .product(
                    name: "DarwinGATT",
                    package: "GATT",
                    condition: .when(platforms: [.macOS])
                ),
                .product(
                    name: "BluetoothLinux",
                    package: "BluetoothLinux",
                    condition: .when(platforms: [.linux])
                )
            ]
        )
    ]
)
