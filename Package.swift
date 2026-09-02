// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LassoCropper",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "LassoCropper",
            path: "Sources/LassoCropper"
        )
    ]
)
