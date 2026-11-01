// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CCUsageBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CCUsageBar", targets: ["CCUsageBar"]),
    ],
    targets: [
        // Pure logic: terminal capture, ANSI cleanup, /usage parsing. No UI.
        .target(name: "UsageCore"),
        // SwiftUI menu bar app.
        .executableTarget(name: "CCUsageBar", dependencies: ["UsageCore"]),
        .testTarget(
            name: "UsageCoreTests",
            dependencies: ["UsageCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
