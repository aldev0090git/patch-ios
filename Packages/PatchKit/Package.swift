// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PatchKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "PatchCore", targets: ["PatchCore"])
    ],
    targets: [
        .target(
            name: "PatchCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PatchCoreTests",
            dependencies: ["PatchCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
