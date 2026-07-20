// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HAP",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .watchOS(.v11),
        .tvOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "HAP",
            targets: ["HAP"]
        ),
        .library(
            name: "HAPCryptoKit",
            targets: ["HAPCryptoKit"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/Bluetooth.git",
            from: "7.5.1"
        ),
        .package(
            url: "https://github.com/PureSwift/GATT.git",
            from: "3.4.1",
            traits: ["BluetoothGATT"]
        ),
        .package(
            url: "https://github.com/PureSwift/TLVCoding.git",
            from: "3.0.0"
        ),
        .package(
            url: "https://github.com/PureSwift/swift-embedded-foundation.git",
            from: "0.1.0"
        ),
        .package(
            url: "https://github.com/apple/swift-crypto.git",
            from: "3.0.0"
        ),
        .package(
            url: "https://github.com/attaswift/BigInt.git",
            from: "5.3.0"
        )
        // swift-binary-parsing is currently omitted as a direct dependency:
        // its swift-syntax pin (602.x) conflicts with TLVCoding 3.0.0 (603.x).
        // Re-add once apple/swift-binary-parsing raises its swift-syntax floor.
    ],
    targets: [
        .target(
            name: "HAP",
            dependencies: [
                .product(name: "Bluetooth", package: "Bluetooth"),
                .product(name: "BluetoothGAP", package: "Bluetooth"),
                .product(name: "BluetoothGATT", package: "Bluetooth"),
                .product(name: "GATT", package: "GATT"),
                .product(name: "TLVCoding", package: "TLVCoding"),
                .product(name: "FoundationEmbedded", package: "swift-embedded-foundation")
            ]
        ),
        .target(
            name: "HAPCryptoKit",
            dependencies: [
                "HAP",
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "FoundationEmbedded", package: "swift-embedded-foundation")
            ]
        ),
        .testTarget(
            name: "HAPCryptoKitTests",
            dependencies: [
                "HAPCryptoKit",
                .product(name: "FoundationEmbedded", package: "swift-embedded-foundation")
            ]
        ),
        .testTarget(
            name: "HAPTests",
            dependencies: [
                "HAP",
                .product(name: "FoundationEmbedded", package: "swift-embedded-foundation")
            ]
        ),
    ]
)
