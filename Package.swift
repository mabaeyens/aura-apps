// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AuraKit",
    platforms: [.macOS(.v13), .iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "AuraKit", targets: ["AuraKit"]),
        .executable(name: "aura-smoke", targets: ["AuraSmoke"]),
        .executable(name: "aura-render", targets: ["AuraRender"]),
    ],
    targets: [
        .target(name: "AuraKit"),
        .executableTarget(name: "AuraSmoke", dependencies: ["AuraKit"]),
        .executableTarget(name: "AuraRender", dependencies: ["AuraKit"]),
        .testTarget(name: "AuraKitTests", dependencies: ["AuraKit"]),
    ]
)
