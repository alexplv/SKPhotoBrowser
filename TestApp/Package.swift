// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "TestApp",
    platforms: [.iOS(.v15)],
    dependencies: [
        .package(path: "../")
    ],
    targets: [
        .executableTarget(
            name: "TestApp",
            dependencies: ["SKPhotoBrowser"],
            path: "Sources")
    ]
)
