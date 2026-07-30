#if canImport(CNativeRegex)
import CNativeRegex
import Foundation

final class NativeCombinedRegex: @unchecked Sendable {
    private let pointer: OpaquePointer

    init?(pattern: String, caseInsensitive: Bool) {
        let units = Array(pattern.utf16)
        var code: Int32 = 0
        var offset = 0
        guard let value = units.withUnsafeBufferPointer({
            nh_regex_compile(
                $0.baseAddress, $0.count, caseInsensitive ? 1 : 0, &code, &offset
            )
        }) else {
            if ProcessInfo.processInfo.environment["NATIVE_HIGHLIGHT_REGEX_DIAGNOSTICS"] != nil {
                FileHandle.standardError.write(
                    Data("PCRE2 error \(code) at UTF-16 offset \(offset)\n".utf8)
                )
            }
            return nil
        }
        pointer = value
    }

    deinit { nh_regex_free(pointer) }

    func firstMatch(
        subject: [UInt16], start: Int, groups: [UInt32]
    ) -> (range: NSRange, dispatchIndex: Int)? {
        let result = subject.withUnsafeBufferPointer { source in
            groups.withUnsafeBufferPointer { dispatch in
                nh_regex_match(
                    pointer,
                    source.baseAddress, source.count, start,
                    dispatch.baseAddress, dispatch.count
                )
            }
        }
        guard result.status == 1 else { return nil }
        return (
            NSRange(location: result.location, length: result.length),
            Int(result.dispatch_index)
        )
    }
}
#endif
