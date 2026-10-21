// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BeijingTime",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "BeijingTimeCore", targets: ["BeijingTimeCore"]),
        .executable(name: "BeijingTime", targets: ["BeijingTimeApp"]),
    ],
    targets: [
        .target(
            name: "BeijingTimeCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "BeijingTimeApp",
            dependencies: ["BeijingTimeCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "BeijingTimeCoreTests",
            dependencies: ["BeijingTimeCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
