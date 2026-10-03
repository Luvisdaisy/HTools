// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyboardGuardPOC",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "KeyboardGuardPOC", targets: ["KeyboardGuardPOC"])],
    targets: [
        .target(name: "KeyboardCore"),
        .executableTarget(name: "KeyboardGuardPOC", dependencies: ["KeyboardCore"]),
        .testTarget(name: "KeyboardCoreTests", dependencies: ["KeyboardCore"])
    ]
)
