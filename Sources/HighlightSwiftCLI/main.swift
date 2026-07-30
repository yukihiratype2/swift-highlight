import Foundation
import HighlightSwift

var language: String?, format="ansi", file: String?
var args=CommandLine.arguments.dropFirst().makeIterator()
while let arg=args.next() {
    switch arg {
    case "-l","--language": language=args.next()
    case "-f","--format": format=args.next() ?? "ansi"
    default: file=arg
    }
}
let data = try file.map { try Data(contentsOf:URL(fileURLWithPath:$0)) }
    ?? FileHandle.standardInput.readDataToEndOfFile()
guard let source=String(data:data,encoding:.utf8) else {
    throw CocoaError(.fileReadInapplicableStringEncoding)
}
let h=try Highlighter.allLanguages()
let result = try language.map { try h.highlight(source,language:$0) }
    ?? h.highlightAuto(source)
switch format {
case "html": print(result.html,terminator:"")
case "tokens": for t in result.tokens { print("\(t.kind.rawValue)\t\(t.text.debugDescription)") }
default: print(result.ansi,terminator:"")
}
