// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexUsage",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CodexUsageCore", targets: ["CodexUsageCore"]),
        .executable(name: "CodexUsageApp", targets: ["CodexUsageApp"]),
    ],
    targets: [
        .target(name: "CodexUsageCore"),
        .executableTarget(name: "CodexUsageApp", dependencies: ["CodexUsageCore"]),
        .testTarget(name: "CodexUsageCoreTests", dependencies: ["CodexUsageCore"]),
    ]
)
