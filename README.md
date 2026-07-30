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
node Tools/migrate-highlightjs.cjs \
  --upstream ../highlightjs-reference \
  --output Sources/NativeHighlight/Resources/Grammars
```

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
| NativeHighlight | 3.18 MB/s | 48.55 MB |
| Highlight.js / Node.js | 2.67 MB/s | 91.03 MB |

That run made the native engine **1.19× faster** overall and used **47% less
peak memory**. Python, C++, and SQL remain slower individually, so the checked-in
benchmark should be treated as a reproducible optimization target rather than
a universal claim about every input.

BSD 3-Clause licensed.
