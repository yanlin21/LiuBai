// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LiuBai",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "LiuBai", targets: ["LiuBai"])
    ],
    targets: [
        .executableTarget(
            name: "LiuBai",
            path: "Sources",
            exclude: ["LiuBaiWidget"],
            sources: ["LiuBai", "Shared"]
        )
    ]
)
