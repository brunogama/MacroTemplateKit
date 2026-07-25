// swift-tools-version: 6.0
// KEEP IN SYNC WITH Package.swift. Everything below line 1 of the two manifests
// must be byte-identical; `Scripts/check-manifests.sh` enforces it in CI. They
// have drifted before -- MacroExamples was added to one and not the other, and
// because a Swift 6 toolchain resolves this file and ignores Package.swift, the
// gap was invisible until someone built on an older toolchain.
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
    .package(url: "https://github.com/swiftlang/swift-syntax.git", "510.0.0"..<"700.0.0")
  ],
  targets: [
    .target(
      name: "MacroTemplateKit",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "MacroTemplateKitTests",
      dependencies: ["MacroTemplateKit"],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    // The example macros are a build target so that they cannot silently rot.
    // They were not one until now, and every one of them had drifted out of
    // date: 57 call sites across 24 files still used the pre-throwing
    // `Renderer.render` API and had not compiled since that change shipped.
    // Documentation nothing compiles is documentation nothing checks.
    .target(
      name: "MacroExamples",
      dependencies: [
        "MacroTemplateKit",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
      ],
      path: "Examples",
      exclude: [
        "README.md",
        "AccessorAndBodyMacros/README.md",
        "ExpressionMacros/README.md",
        "ExtensionMacros/README.md",
        "MemberMacros/README.md",
        "PeerMacros/README.md",
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
  ]
)
