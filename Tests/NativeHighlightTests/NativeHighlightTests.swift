import XCTest
@testable import NativeHighlight

final class NativeHighlightTests:XCTestCase {
    func testCatalogAndCoverage() throws {
        let catalog=try GeneratedGrammarCatalog()
        XCTAssertGreaterThanOrEqual(catalog.languages.count,192)
        let h=GeneratedModeHighlighter(catalog:catalog)
        for (language,source) in [
            ("swift","func greet(_ name: String) { print(\"Hi, \\(name)\") }"),
            ("javascript","const answer = async () => await Promise.resolve(42);"),
            ("python","def greet(name):\n return f'Hi, {name}'"),
            ("xml","<main class=\"page\">Hello</main>"),
            ("brainfuck","++++[>++++++++<-]>+.")
        ] {
            let r=try h.highlight(source,language:language)
            XCTAssertEqual(r.tokens.map(\.text).joined(),source,language)
            XCTAssertGreaterThan(r.tokens.count,1,language)
        }
    }
    func testHTMLIsEscaped() throws {
        let source = #"let café = "👩🏽‍💻 <tag> &""#
        let highlighter = try Highlighter.allLanguages()
        let r=try highlighter.highlight(source,language:"swift")
        XCTAssertTrue(r.html.contains("&lt;tag&gt; &amp;"))
        XCTAssertEqual(
            try highlighter.highlightHTML(source, language: "swift"),
            r.html
        )
    }
}
