// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HighlightSwift",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9)],
    products: [
        .library(name: "HighlightSwift", targets: ["HighlightSwift"]),
        .executable(name: "highlight-swift", targets: ["HighlightSwiftCLI"]),
        .executable(name: "highlight-swift-benchmark", targets: ["HighlightSwiftBenchmark"])
    ],
    targets: [
        .target(
            name: "CNativeRegex",
            path: "Sources/CNativeRegex",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("pcre2-16"),
                .linkedLibrary("pthread")
            ]
        ),
        .target(
            name: "HighlightSwift",
            dependencies: [
                .target(name: "CNativeRegex", condition: .when(platforms: [.linux]))
            ],
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "HighlightSwiftCLI", dependencies: ["HighlightSwift"]),
        .executableTarget(
            name: "HighlightSwiftBenchmark",
            dependencies: ["HighlightSwift"],
            path: "Benchmarks",
            exclude: ["compare.py", "highlightjs.cjs", "workloads.json"]
        ),
        .testTarget(name: "HighlightSwiftTests", dependencies: ["HighlightSwift"])
    ]
)
