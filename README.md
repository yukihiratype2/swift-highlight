# NativeHighlight

A native Swift syntax highlighter generated from Highlight.js grammar
definitions. The shipped runtime executes no JavaScript.

```swift
let highlighter = try Highlighter.allLanguages()
let result = try highlighter.highlight(source, language: "swift")
print(result.html)

// Avoid token allocation when HTML is the only output you need.
let html = try highlighter.highlightHTML(source, language: "swift")
```

The build-time generator migrates the complete upstream language catalog into
lazy per-language resources:

```console
Scripts/generate-grammars.sh ../highlightjs-reference
```

Generated grammar JSON is intentionally excluded from Git. A source checkout
therefore requires generation before `swift build` or `swift test`. Release
archives contain the generated resources and are ready to build directly.

The optimized engine exports Highlight.js's compiled combined matchers and
dispatch tables, parses with UTF-16 integer offsets, and materializes public
Swift token strings only once at the end. On Linux, combined matchers use
PCRE2-16 JIT through a small C interoperability target. Match buffers are
reused per thread, so concurrent highlighting does not serialize on a regex
lock. Apple platforms retain the Foundation regex fallback.

Run the cross-runtime benchmark with:

```console
swift build -c release --product native-highlight-benchmark
cp .build/release/native-highlight-benchmark .verify/native-highlight-benchmark
python3 Benchmarks/compare.py
```

The benchmark renders final HTML in both implementations, runs three warmups
and 25 measured iterations per workload, then reports the median of five fresh
processes for both runtimes. On the project
cloud runner with Swift 6.0.3, Node.js 24.14.0, Highlight.js 11.11.2, and the
eight checked-in workloads:

| Runtime | Throughput | Peak RSS |
|---|---:|---:|
| NativeHighlight | 6.82 MB/s | 48.52 MB |
| Highlight.js / Node.js | 2.50 MB/s | 90.87 MB |

That run made the native engine **2.72× faster** overall and used **47% less
peak memory**. The native engine led all eight workloads, with SQL essentially
tied, so the checked-in benchmark should be treated as a reproducible
optimization target rather than a universal claim about every input.

## Releases

The `Generate release packages` GitHub Actions workflow installs Swift 6.0.3,
Node.js, and PCRE2 on Ubuntu, regenerates all grammars from pinned Highlight.js
commit `d9b538d03e571ad631d8c4574a1abda4ca65d62f`, and runs the release test suite.

A manual workflow run uploads build artifacts. Pushing a tag such as `v0.1.0`
also creates a GitHub Release containing:

- `NativeHighlight-<version>.tar.gz`
- `NativeHighlight-<version>.zip`
- `NativeHighlight-Grammars-<version>.tar.gz`
- `SHA256SUMS`

For regular releases, update `VERSION` on `main`. The `Tag version` workflow
creates the matching `v<version>` tag, which triggers release packaging.
If a tag already exists and its release assets need rebuilding, update
`RELEASE_REQUEST` with a new retry marker.

BSD 3-Clause licensed.
