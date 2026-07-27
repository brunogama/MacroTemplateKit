// swift-tools-version: 5.10
// Standalone benchmark package. Kept out of the root manifest so benchmark-only
// dependencies and executable targets never affect library consumers.
import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "603.0.2"),
    ],
    targets: [
        .executableTarget(
            name: "RenderEngineBench",
            dependencies: [
                .product(name: "MacroTemplateKit", package: "MacroTemplateKit"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        )
    ]
)
