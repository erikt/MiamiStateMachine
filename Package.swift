// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MiamiStateMachine",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(
            name: "MiamiStateMachine",
            targets: ["MiamiStateMachine"]),
        .library(
            name: "Graph",
            targets: ["Graph"]),
        .library(
            name: "DataStructures",
            targets: ["DataStructures"]),
    ],
    dependencies: [
        .package( url: "https://github.com/apple/swift-collections.git", .upToNextMajor(from: "1.0.2"))
    ],
    targets: [
        .target(
            name: "MiamiStateMachine",
            dependencies: [
                "Graph",
                .product(name: "Collections", package: "swift-collections"),
            ]),
        .target(
            name: "Graph",
            dependencies: [ "DataStructures" ]),
        .target(
            name: "DataStructures",
            dependencies: [
            ]),
        .testTarget(
            name: "MiamiStateMachineTests",
            dependencies: ["MiamiStateMachine"]),
    ]
)
