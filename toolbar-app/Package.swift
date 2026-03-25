// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OnAirMenuBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "OnAirMenuBar",
            path: "Sources/OnAirMenuBar"
        )
    ]
)
