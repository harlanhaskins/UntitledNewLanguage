// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NewLang",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-subprocess", from: "0.1.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/llvm-swift/lite", branch: "master")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "NewLang",
            dependencies: [
                "CompilerDriver", "SSA", "Lexer", "Parser", "TypeSystem",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "Base",
            dependencies: []
        ),
        .target(
            name: "Lexer",
            dependencies: ["Base"],
        ),
        .target(
            name: "Types",
            dependencies: ["Base"]
        ),
        .target(
            name: "AST",
            dependencies: ["Base", "Types"]
        ),
        .target(
            name: "Parser",
            dependencies: ["Base", "AST"]
        ),
        .target(
            name: "TypeSystem",
            dependencies: ["Base", "AST", "Types"]
        ),
        .target(
            name: "CompilerDriver",
            dependencies: [
                "Lexer", "Base", "AST", "Parser", "TypeSystem", "Types", "SSA",
                .product(name: "Subprocess", package: "swift-subprocess"),
            ]
        ),
        .target(
            name: "SSA",
            dependencies: ["Base", "Types", "AST"]
        ),
        .executableTarget(
            name: "lite",
            dependencies: [
                .product(name: "LiteSupport", package: "lite"),
                "NewLang"
            ]
        ),
    ]
)
