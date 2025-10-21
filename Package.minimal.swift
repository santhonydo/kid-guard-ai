// swift-tools-version: 5.9
// Minimal Package.swift for quick testing without heavy dependencies

import PackageDescription

let package = Package(
    name: "KidGuardAI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "KidGuardAIDaemon", targets: ["KidGuardAIDaemon"]),
        .executable(name: "ManualTest", targets: ["ManualTest"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "KidGuardAIDaemon",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "KidGuardAIDaemon"
        ),
        .executableTarget(
            name: "ManualTest",
            dependencies: [],
            path: "Tests",
            sources: ["ManualTest.swift"]
        )
    ]
)
