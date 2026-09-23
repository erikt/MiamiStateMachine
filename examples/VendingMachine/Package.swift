// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "VendingMachine",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "vending-server", targets: ["VendingServer"]),
        .executable(name: "vend", targets: ["VendingClient"]),
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
    ],
    targets: [
        // The types a server and its clients share, and read from JSON.
        .target(
            name: "VendingModel",
            dependencies: [
                .product(name: "MiamiStateMachine", package: "MiamiStateMachine"),
                .product(name: "MiamiMacros", package: "MiamiStateMachine"),
            ]
        ),
        .target(
            name: "Vending",
            dependencies: [
                "VendingModel",
                .product(name: "MiamiStateMachine", package: "MiamiStateMachine"),
                .product(name: "MiamiDiagrams", package: "MiamiStateMachine"),
            ]
        ),
        .executableTarget(
            name: "VendingServer",
            dependencies: [
                "Vending",
                "VendingModel",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ]
        ),
        .executableTarget(
            name: "VendingClient",
            dependencies: [
                "VendingModel",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "VendingModelTests",
            dependencies: [
                "VendingModel",
                .product(name: "MiamiStateMachine", package: "MiamiStateMachine"),
            ]
        ),
        .testTarget(
            name: "VendingTests",
            dependencies: [
                "Vending",
                "VendingModel",
                .product(name: "MiamiStateMachine", package: "MiamiStateMachine"),
            ]
        ),
    ]
)
