// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MiamiStateMachine",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        // The MiamiGraph and MiamiDataStructures targets are internal to the package and deliberately not vended as products.
        .library(
            name: "MiamiStateMachine",
            targets: ["MiamiStateMachine"]),
        // An observable state machine for user interfaces, like SwiftUI.
        .library(
            name: "MiamiUI",
            targets: ["MiamiUI"]),
        // Diagrams of a state machine, for Graphviz and Mermaid.
        .library(
            name: "MiamiDiagrams",
            targets: ["MiamiDiagrams"]),
    ],
    dependencies: [
        // 1.1.0 is the first version with the Heap. Deque is Sendable from 1.0.6.
        .package( url: "https://github.com/apple/swift-collections.git", .upToNextMajor(from: "1.1.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "MiamiStateMachine",
            dependencies: [
                "MiamiGraph",
                .product(name: "Collections", package: "swift-collections")
            ]),
        .target(
            name: "MiamiUI",
            dependencies: ["MiamiStateMachine"]),
        .target(
            name: "MiamiDiagrams",
            dependencies: ["MiamiStateMachine"]),
        // Internal targets are prefixed with Miami, as module names have
        // to be unique among all packages a client depends on.
        .target(
            name: "MiamiGraph",
            dependencies: ["MiamiDataStructures"]),
        .target(
            name: "MiamiDataStructures",
            dependencies: [
                .product(name: "DequeModule", package: "swift-collections"),
                .product(name: "HeapModule", package: "swift-collections"),
            ]),
        .testTarget(
            name: "MiamiStateMachineTests",
            dependencies: ["MiamiStateMachine"]),
        .testTarget(
            name: "MiamiUITests",
            dependencies: ["MiamiUI", "MiamiStateMachine"]),
        .testTarget(
            name: "MiamiDiagramsTests",
            dependencies: ["MiamiDiagrams", "MiamiStateMachine"]),
        .testTarget(
            name: "MiamiGraphTests",
            dependencies: ["MiamiGraph"]),
        .testTarget(
            name: "MiamiDataStructuresTests",
            dependencies: ["MiamiDataStructures"]),
    ]
)
