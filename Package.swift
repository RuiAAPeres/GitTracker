// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GitTracker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GitTracker", targets: ["GitTracker"])
    ],
    targets: [
        .executableTarget(
            name: "GitTracker",
            path: "Sources/GitTracker"
        ),
        .testTarget(
            name: "GitTrackerTests",
            dependencies: ["GitTracker"],
            path: "Tests/GitTrackerTests"
        )
    ]
)
