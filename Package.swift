// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KidGuardAI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "KidGuardAI", targets: ["KidGuardAI"]),
        .executable(name: "KidGuardAIDaemon", targets: ["KidGuardAIDaemon"]),
        .executable(name: "ManualTest", targets: ["ManualTest"]),
        .library(name: "KidGuardCore", targets: ["KidGuardCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        .package(url: "https://github.com/RevenueCat/purchases-ios.git", from: "4.0.0")
    ],
    targets: [
        .executableTarget(
            name: "KidGuardAI",
            dependencies: ["KidGuardCore"],
            path: "KidGuardAI",
            exclude: ["KidGuardAI.xcodeproj", "KidGuardAIFilterExtension"]
        ),
        .executableTarget(
            name: "KidGuardAIDaemon", 
            dependencies: [
                "KidGuardCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "KidGuardAIDaemon"
        ),
        .target(
            name: "KidGuardCore",
            dependencies: [
                "Alamofire",
                .product(name: "RevenueCat", package: "purchases-ios")
            ],
            path: "KidGuardCore",
            resources: [
                .process("Resources/KidGuardAI.xcdatamodeld")
            ]
        ),
        .executableTarget(
            name: "ManualTest",
            dependencies: [],
            path: "Tests",
            sources: ["ManualTest.swift"]
        ),
        .testTarget(
            name: "KidGuardAITests",
            dependencies: ["KidGuardCore"],
            path: "Tests",
            exclude: ["ManualTest.swift"]
        )
    ]
)