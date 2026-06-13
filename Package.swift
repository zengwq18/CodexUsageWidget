// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexUsageWidget",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodexUsageWidget", targets: ["CodexUsageWidget"]),
        .executable(name: "CodexUsageCoreChecks", targets: ["CodexUsageCoreChecks"]),
        .library(name: "CodexUsageCore", targets: ["CodexUsageCore"])
    ],
    targets: [
        .target(name: "CodexUsageCore"),
        .executableTarget(
            name: "CodexUsageWidget",
            dependencies: ["CodexUsageCore"]
        ),
        .executableTarget(
            name: "CodexUsageCoreChecks",
            dependencies: ["CodexUsageCore"],
            path: "Checks/CodexUsageCoreChecks"
        )
    ]
)
