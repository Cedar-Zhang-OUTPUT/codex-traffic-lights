// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexLight",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "CodexLight", targets: ["CodexLight"])],
    targets: [
        .target(name: "LightCore"),
        .executableTarget(name: "CodexLight", dependencies: ["LightCore"]),
        .testTarget(name: "LightCoreTests", dependencies: ["LightCore"])
    ]
)
