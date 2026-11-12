// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Healthify",
    platforms: [.iOS(.v17)],
    products: [
        .executable(name: "Healthify", targets: ["HealthifyApp"])
    ],
    targets: [
        // Portable domain logic: Foundation only, no UI, no network.
        .target(name: "HealthifyCore"),
        // iOS app: SwiftUI views + camera + file import/export.
        .executableTarget(
            name: "HealthifyApp",
            dependencies: ["HealthifyCore"]
        ),
        .testTarget(
            name: "HealthifyCoreTests",
            dependencies: ["HealthifyCore"]
        )
    ]
)
