#if canImport(HighlightSwift)
import HighlightSwift
#endif
import Foundation
#if canImport(Glibc)
import Glibc
#endif

struct Workload { let name:String; let language:String; let source:String }
func now() -> Double {
    var t=timespec(); clock_gettime(CLOCK_MONOTONIC,&t)
    return Double(t.tv_sec)+Double(t.tv_nsec)/1e9
}
func peakRSS() -> Int {
    #if canImport(Glibc)
    var u=rusage(); _=getrusage(Int32(RUSAGE_SELF.rawValue),&u); return Int(u.ru_maxrss)
    #else
    return 0
    #endif
}
let grammarURL=URL(fileURLWithPath:"Sources/HighlightSwift/Resources/Grammars")
let raw=try JSONSerialization.jsonObject(
    with:Data(contentsOf:URL(fileURLWithPath:"Benchmarks/workloads.json"))
) as! [[String:Any]]
let workloads=raw.map {
    Workload(
        name:$0["name"] as! String, language:$0["language"] as! String,
        source:Array(repeating:$0["snippet"] as! String,count:$0["repeat"] as! Int).joined(separator:"\n")
    )
}
let initStart=now()
let highlighter=GeneratedModeHighlighter(catalog:try GeneratedGrammarCatalog(directoryURL:grammarURL))
let initSeconds=now()-initStart
let iterations=25,warmups=3
var checksum=0, rows=[[String:Any]](), totalBytes=0
var totalSeconds=0.0
for w in workloads {
    let cold=now(); checksum += try highlighter.highlightHTML(w.source,language:w.language).utf8.count
    let coldSeconds=now()-cold
    for _ in 0..<warmups {
        checksum += try highlighter.highlightHTML(w.source,language:w.language).utf8.count
    }
    let start=now()
    for _ in 0..<iterations {
        checksum += try highlighter.highlightHTML(w.source,language:w.language).utf8.count
    }
    let seconds=now()-start, bytes=w.source.utf8.count
    totalBytes += bytes*iterations; totalSeconds += seconds
    rows.append([
        "name":w.name,"language":w.language,"bytes":bytes,"seconds":seconds,
        "first_highlight_seconds":coldSeconds,
        "mb_per_second":Double(bytes*iterations)/1e6/seconds
    ])
}
let output:[String:Any]=[
    "runtime":"native-swift","checksum":checksum,"initialization_seconds":initSeconds,
    "iterations":iterations,"warmups":warmups,"peak_rss_kb":peakRSS(),
    "total_bytes":totalBytes,"total_seconds":totalSeconds,
    "total_mb_per_second":Double(totalBytes)/1e6/totalSeconds,"workloads":rows
]
print(String(decoding:try JSONSerialization.data(withJSONObject:output,options:.sortedKeys),as:UTF8.self))
