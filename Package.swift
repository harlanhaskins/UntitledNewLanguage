// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NewLang",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-subprocess", from: "0.1.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "NewLang",
            dependencies: ["CompilerDriver"]
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
            name: "CodeGen",
            dependencies: ["Base", "AST", "Types"]
        ),
        .target(
            name: "CompilerDriver", 
            dependencies: [
                "Lexer", "Base", "AST", "Parser", "TypeSystem", "Types", "CodeGen",
                .product(name: "Subprocess", package: "swift-subprocess")
            ]
        )
    ]
)
