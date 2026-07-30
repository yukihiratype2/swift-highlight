# HighlightSwift

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://www.swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%2013%20%7C%20iOS%2016%20%7C%20tvOS%2016%20%7C%20watchOS%209%20%7C%20Linux-lightgrey)](#requirements)
[![License: BSD 3-Clause](https://img.shields.io/badge/license-BSD%203--Clause-blue.svg)](LICENSE)

A fast, native Swift syntax highlighter generated from the [Highlight.js](https://highlightjs.org) language grammars. HighlightSwift produces HTML, ANSI-colored text, or structured tokens without executing JavaScript at runtime.

## Features

- More than 190 language grammars generated from Highlight.js
- Explicit language selection or automatic language detection
- HTML output compatible with Highlight.js CSS classes
- ANSI output for terminal applications
- Structured tokens with kinds and source ranges
- Lazy, per-language grammar loading
- Thread-local matcher reuse for concurrent highlighting
- Native PCRE2-16 JIT matching on Linux
- No runtime JavaScript dependency

## Requirements

- Swift 5.9 or later
- macOS 13+, iOS 16+, tvOS 16+, or watchOS 9+
- Linux with the PCRE2 development library installed

On Ubuntu or Debian, install the Linux dependency with:

```console
sudo apt-get install libpcre2-dev
```

## Installation

### Swift Package Manager

Add HighlightSwift to your package dependencies:

```swift
dependencies: [
    .package(
        url: "https://github.com/yukihiratype2/swift-highlight.git",
        from: "0.1.0"
    )
]
```

Then add the library to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "HighlightSwift", package: "swift-highlight")
    ]
)
```

Release archives include the generated grammar resources and are ready to build. A checkout of the repository's `main` branch requires the grammar-generation step described in [Building from source](#building-from-source).

## Library usage

Import the package and create a highlighter containing the full language catalog:

```swift
import HighlightSwift

let highlighter = try Highlighter.allLanguages()
let source = """
struct Greeter {
    func greet(name: String) {
        print("Hello, \\(name)!")
    }
}
"""

let result = try highlighter.highlight(source, language: "swift")

print(result.html)
print(result.ansi)
print(result.relevance)
```

### Render HTML directly

If HTML is the only output you need, avoid allocating the public token array:

```swift
let html = try highlighter.highlightHTML(source, language: "swift")
```

The generated markup uses Highlight.js-compatible classes such as `hljs-keyword` and `hljs-string`. Apply a [Highlight.js theme](https://github.com/highlightjs/highlight.js/tree/main/src/styles) or provide your own CSS.

### Detect the language automatically

```swift
let result = highlighter.highlightAuto(source)

print(result.language ?? "unknown")
print(result.html)
```

### Work with tokens

```swift
let result = try highlighter.highlight(source, language: "swift")

for token in result.tokens {
    print(token.kind.rawValue, token.text, token.range)
}
```

Each `HighlightToken` contains a `TokenKind`, its original text, and its range in the source string. Requesting an unknown language throws `HighlightError.unknownLanguage`.

## Command-line usage

Build the CLI:

```console
swift build -c release --product highlight-swift
```

Highlight a file in the terminal:

```console
.build/release/highlight-swift --language swift Example.swift
```

Read from standard input and emit HTML:

```console
printf 'let answer = 42' | .build/release/highlight-swift --language swift --format html
```

Let HighlightSwift detect the language and print tokens:

```console
.build/release/highlight-swift --format tokens Example.swift
```

Available output formats are `ansi` (the default), `html`, and `tokens`.

## Building from source

Generated grammar JSON is intentionally excluded from Git. To build a source checkout, clone the pinned Highlight.js revision and generate the resources first:

```console
git clone https://github.com/highlightjs/highlight.js.git .build/highlightjs
highlightjs_ref="$(tr -d '[:space:]' < HIGHLIGHTJS_COMMIT)"
git -C .build/highlightjs checkout "$highlightjs_ref"
Scripts/generate-grammars.sh .build/highlightjs
swift test
```

The generator requires Node.js. On Linux, install PCRE2 before building.

## Performance

The included benchmark compares final HTML rendering in HighlightSwift and Highlight.js. It runs three warmups and 25 measured iterations per workload, then reports the median of five fresh processes.

On the project cloud runner using Swift 6.0.3, Node.js 24.14.0, Highlight.js 11.11.2, and the eight checked-in workloads:

| Runtime | Throughput | Peak RSS |
| --- | ---: | ---: |
| HighlightSwift | 6.82 MB/s | 48.52 MB |
| Highlight.js / Node.js | 2.50 MB/s | 90.87 MB |

In that run, HighlightSwift was **2.72× faster** overall and used **47% less peak memory**. Results vary by platform and input; treat the checked-in benchmark as a reproducible optimization target rather than a universal performance claim.

Run it locally with:

```console
swift build -c release --product highlight-swift-benchmark
cp .build/release/highlight-swift-benchmark .verify/highlight-swift-benchmark
python3 Benchmarks/compare.py
```

## How it works

At build time, HighlightSwift converts Highlight.js grammar definitions into lazy, per-language resources. At runtime, the engine executes compiled combined matchers and dispatch tables using UTF-16 integer offsets, then materializes Swift token strings once at the end.

Linux uses PCRE2-16 JIT through a small C interoperability target. Apple platforms use the Foundation regular-expression fallback. Match buffers are reused per thread, so concurrent highlighting does not serialize on a shared regular-expression lock.

## Upstream synchronization

The **Sync Highlight.js** workflow runs every Monday and can also be started manually. It compares `HIGHLIGHTJS_COMMIT` with the latest commit on Highlight.js's default branch. When an update is available, the workflow:

1. Checks out the new upstream revision.
2. Regenerates the full grammar catalog.
3. Runs the release test suite.
4. Uploads validation packages as GitHub Actions artifacts.
5. Opens a pull request that updates the pinned revision.

Merging that pull request makes subsequent HighlightSwift releases use the validated upstream revision. The pin keeps builds reproducible while still making upstream updates automatic.

## Releases

The release workflow regenerates all grammars from the revision in `HIGHLIGHTJS_COMMIT`, runs the release test suite, and packages generated sources.

Tagged releases contain:

- `HighlightSwift-<version>.tar.gz`
- `HighlightSwift-<version>.zip`
- `HighlightSwift-Grammars-<version>.tar.gz`
- `SHA256SUMS`

Maintainers can update `VERSION` on `main` to create the corresponding `v<version>` tag through the **Tag version** workflow. To rebuild assets for an existing tag, update `RELEASE_REQUEST` with a new retry marker.

## Contributing

Bug reports and pull requests are welcome. For changes to generated grammars or the matching engine, run the grammar generator and the full test suite before submitting your change:

```console
Scripts/generate-grammars.sh .build/highlightjs
swift test
```

Please include a focused test for behavior changes when practical.

## License

HighlightSwift is available under the [BSD 3-Clause License](LICENSE).
