// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MacroTemplateKit",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [
    .library(
      name: "MacroTemplateKit",
      targets: ["MacroTemplateKit"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
  ],
  targets: [
    .target(
      name: "MacroTemplateKit",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "MacroTemplateKitTests",
      dependencies: ["MacroTemplateKit"]
    ),
  ]
)
