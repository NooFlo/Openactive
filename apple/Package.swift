// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Openactive",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    dependencies: [
        // Test-only; Xcode ships Testing itself, CLT does not.
        .package(url: "https://github.com/apple/swift-testing", from: "0.12.0"),
    ],
    targets: [
        .target(
            name: "OpenactiveCore",
            path: "Sources/OpenactiveCore"
        ),
        .executableTarget(
            name: "OpenactiveApp",
            dependencies: ["OpenactiveCore"],
            path: "Sources/OpenactiveApp"
        ),
        .executableTarget(
            name: "OpenactiveWatch",
            dependencies: ["OpenactiveCore"],
            path: "Sources/OpenactiveWatch"
        ),
        .testTarget(
            name: "OpenactiveCoreTests",
            dependencies: [
                "OpenactiveCore",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/OpenactiveCoreTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
