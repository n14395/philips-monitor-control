// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PhilipsMultiView",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PhilipsMultiView",
            path: "Sources"
        ),
    ]
)
