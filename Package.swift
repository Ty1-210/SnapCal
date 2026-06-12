// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnapCal",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SnapCal",
            path: "Sources/SnapCal",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("Vision"),
                .linkedFramework("EventKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
    ]
)
