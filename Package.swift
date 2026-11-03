// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Noonchi",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Noonchi", targets: ["Noonchi"]),
    ],
    targets: [
        // Pure logic: terminal capture, ANSI cleanup, /usage parsing. No UI.
        .target(name: "UsageCore"),
        // SwiftUI menu bar app.
        .executableTarget(name: "Noonchi", dependencies: ["UsageCore"]),
        .testTarget(
            name: "UsageCoreTests",
            dependencies: ["UsageCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
