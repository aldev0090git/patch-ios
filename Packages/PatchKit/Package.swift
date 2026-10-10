// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PatchKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "PatchCore", targets: ["PatchCore"]),
        .library(name: "PatchStore", targets: ["PatchStore"])
    ],
    targets: [
        // Pure domain. Foundation only — no SwiftData, no SwiftUI.
        .target(
            name: "PatchCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Persistence. The only place in the codebase that knows SwiftData
        // exists. A package rather than app code so its tests run under
        // `swift test` in milliseconds, with no simulator and no app host.
        .target(
            name: "PatchStore",
            dependencies: ["PatchCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PatchCoreTests",
            dependencies: ["PatchCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PatchStoreTests",
            dependencies: ["PatchStore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
