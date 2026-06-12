// swift-tools-version: 5.9

import PackageDescription
import CompilerPluginSupport

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
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0")
    ],
    targets: [
        .target(
            name: "ZWB_Codable",
            dependencies: ["ZWB_CodableMacros"]
        ),
        .macro(
            name: "ZWB_CodableMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .executableTarget(
            name: "ZWB_CodableGenerator"
        ),
        .testTarget(
            name: "ZWB_CodableTests",
            dependencies: ["ZWB_Codable"]
        ),
        .testTarget(
            name: "ZWB_CodableMacroTests",
            dependencies: [
                "ZWB_CodableMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ]
        )
    ]
)
