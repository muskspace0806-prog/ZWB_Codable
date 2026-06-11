// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "ZWB_Codable",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "ZWB_Codable",
            targets: ["ZWB_Codable"]
        ),
        .executable(
            name: "zwb-codable-generate",
            targets: ["ZWB_CodableGenerator"]
        )
    ],
    targets: [
        .target(
            name: "ZWB_Codable"
        ),
        .executableTarget(
            name: "ZWB_CodableGenerator"
        ),
        .testTarget(
            name: "ZWB_CodableTests",
            dependencies: ["ZWB_Codable"]
        )
    ]
)
