// swift-tools-version: 5.9
// Package.swift — Swift Package Manager config for `swift test` only.
// The Makefile build uses `swiftc Sources/*.swift` directly; this file does NOT affect `make`.
import PackageDescription

let package = Package(
    name: "Jottr",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "Grain",
            path: "Sources",
            // Exclude App.swift — it contains @main which conflicts with the test runner's entry point.
            // The Makefile build compiles all Sources/*.swift directly via swiftc and is unaffected.
            exclude: ["App.swift"]
        ),
        .testTarget(
            name: "SnippetEngineTests",
            dependencies: ["Grain"],
            path: "Tests/SnippetEngineTests"
        ),
        .testTarget(
            name: "SnippetStoreTests",
            dependencies: ["Grain"],
            path: "Tests/SnippetStoreTests"
        ),
    ]
)
