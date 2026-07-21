// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Examples",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "posix-smart-lock",
            targets: ["POSIXSmartLock"]
        ),
        .executable(
            name: "posix-light-bulb",
            targets: ["POSIXLightBulb"]
        )
    ],
    dependencies: [
        .package(name: "HAP", path: ".."),
        .package(
            url: "https://github.com/PureSwift/GATT.git",
            from: "4.0.0",
            traits: ["BluetoothGATT"]
        ),
        // BluetoothLinux tracks Bluetooth's master branch, so the examples pin both to
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
        // Platform support shared by every example: POSIX implementations of the library's
        // abstractions, and the Bluetooth transport for each platform.
        .target(
            name: "POSIXHAP",
            dependencies: [
                .product(name: "HAP", package: "HAP"),
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
            ],
            path: "POSIXHAP"
        ),
        .executableTarget(
            name: "POSIXSmartLock",
            dependencies: [
                "POSIXHAP",
                .product(name: "HAP", package: "HAP"),
                .product(name: "HAPCryptoKit", package: "HAP")
            ],
            path: "POSIX-Smart-Lock",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "POSIXLightBulb",
            dependencies: [
                "POSIXHAP",
                .product(name: "HAP", package: "HAP"),
                .product(name: "HAPCryptoKit", package: "HAP")
            ],
            path: "POSIX-Light-Bulb",
            exclude: ["README.md"]
        )
    ]
)
