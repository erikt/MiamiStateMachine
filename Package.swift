// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
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
        // Macros writing what a state machine needs, like the triggers of events.
        // A library of its own, as a macro needs swift-syntax to be built.
        .library(
            name: "MiamiMacros",
            targets: ["MiamiMacros"]),
    ],
    dependencies: [
        // 1.1.0 is the first version with the Heap. Deque is Sendable from 1.0.6.
        .package( url: "https://github.com/apple/swift-collections.git", .upToNextMajor(from: "1.1.0")),
        // A wide range, as an app can only have one version of swift-syntax,
        // which all the macros it uses have to agree on.
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"700.0.0"),
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
        .target(
            name: "MiamiMacros",
            dependencies: ["MiamiMacrosPlugin", "MiamiStateMachine"]),
        // The compiler plugin expanding the macros of MiamiMacros.
        .macro(
            name: "MiamiMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]),
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
            name: "MiamiMacrosTests",
            dependencies: [
                "MiamiMacros",
                "MiamiMacrosPlugin",
                "MiamiStateMachine",
                .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
            ]),
        .testTarget(
            name: "MiamiGraphTests",
            dependencies: ["MiamiGraph"]),
        .testTarget(
            name: "MiamiDataStructuresTests",
            dependencies: ["MiamiDataStructures"]),
    ]
)
