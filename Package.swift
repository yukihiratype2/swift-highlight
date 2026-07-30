// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NativeHighlight",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9)],
    products: [
        .library(name: "NativeHighlight", targets: ["NativeHighlight"]),
        .executable(name: "native-highlight", targets: ["NativeHighlightCLI"]),
        .executable(name: "native-highlight-benchmark", targets: ["NativeHighlightBenchmark"])
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
            name: "NativeHighlight",
            dependencies: [
                .target(name: "CNativeRegex", condition: .when(platforms: [.linux]))
            ],
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "NativeHighlightCLI", dependencies: ["NativeHighlight"]),
        .executableTarget(
            name: "NativeHighlightBenchmark",
            dependencies: ["NativeHighlight"],
            path: "Benchmarks",
            exclude: ["compare.py", "highlightjs.cjs", "workloads.json"]
        ),
        .testTarget(name: "NativeHighlightTests", dependencies: ["NativeHighlight"])
    ]
)
