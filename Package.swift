// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Alttab",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "AlttabCore"),
        .executableTarget(name: "AlttabApp", dependencies: ["AlttabCore"]),
        .testTarget(name: "AlttabCoreTests", dependencies: ["AlttabCore"]),
    ]
)
