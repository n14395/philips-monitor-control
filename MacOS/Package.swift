// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PhilipsMultiView",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PhilipsMultiView",
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        ),
    ]
)
