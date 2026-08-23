// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "EkitapligimIOS",
    defaultLocalization: "tr",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(name: "EkitapligimCore", targets: ["EkitapligimCore"])
    ],
    targets: [
        .target(
            name: "EkitapligimCore",
            path: "Sources/EkitapligimCore",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EkitapligimCoreTests",
            dependencies: ["EkitapligimCore"],
            path: "Tests/EkitapligimCoreTests"
        )
    ]
)
