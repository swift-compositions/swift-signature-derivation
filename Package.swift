// swift-tools-version: 6.4

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "swift-signature-derivation",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "Signature Derivation", targets: ["Signature Derivation"]),
        .library(name: "Signature Derivation Core", targets: ["Signature Derivation Core"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-either.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-optic.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-operation.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-coproduct-derivation.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-eliminator-derivation.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-prism-derivation.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-product-derivation.git", branch: "main"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "603.0.2"..<"604.0.0"),
    ],
    targets: [
        .target(
            name: "Signature Derivation Core",
            dependencies: [
                .product(name: "Coproduct Derivation Core", package: "swift-coproduct-derivation"),
                .product(name: "Eliminator Derivation Core", package: "swift-eliminator-derivation"),
                .product(name: "Prism Derivation Core", package: "swift-prism-derivation"),
                .product(name: "Product Derivation Core", package: "swift-product-derivation"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        ),
        .macro(
            name: "Signature Derivation Macros",
            dependencies: [
                "Signature Derivation Core",
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Signature Derivation",
            dependencies: [
                "Signature Derivation Macros",
                .product(name: "Either", package: "swift-either"),
                .product(name: "Operation", package: "swift-operation"),
                .product(name: "Optic", package: "swift-optic"),
            ]
        ),
        .testTarget(
            name: "Signature Derivation Tests",
            dependencies: [
                "Signature Derivation",
                "Signature Derivation Core",
                .product(name: "Either", package: "swift-either"),
                .product(name: "Product Derivation", package: "swift-product-derivation"),
                .product(name: "Product Derivation Core", package: "swift-product-derivation"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("MoveOnlyTuples"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]
    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
