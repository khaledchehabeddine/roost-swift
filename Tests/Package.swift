// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RoostConsumer",
    platforms: [.iOS(.v13)],
    dependencies: [.package(name: "Roost", path: "../.candidate")],
    targets: [.testTarget(
        name: "ConsumerTests",
        dependencies: [.product(name: "Roost", package: "Roost")],
        path: "ConsumerTests"
    )]
)
