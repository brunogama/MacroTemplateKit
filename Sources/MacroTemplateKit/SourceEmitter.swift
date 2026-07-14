import SwiftSyntax
import SwiftSyntaxBuilder

/// Walks template values appending Swift source text to a single buffer.
/// Renderer parses the buffer once per fragment. Internal by design:
/// the emitter's output format is an implementation detail of Renderer.
enum SourceEmitter {
    static func emit<A: Sendable>(_ template: Template<A>, into buffer: inout String) {
        switch template {
        case .literal(let value):
            emit(value, into: &buffer)
        case .variable(let name, _):
            buffer.append(name)
        default:
            // Temporary during migration: Task 3 fills in every case and
            // deletes this default so the switch is compiler-exhaustive.
            fatalError("SourceEmitter: unhandled template case \(template)")
        }
    }

    static func emit(_ value: LiteralValue, into buffer: inout String) {
        switch value {
        case .integer(let int): buffer.append(String(int))
        case .double(let double): buffer.append(String(double))
        case .boolean(let bool): buffer.append(bool ? "true" : "false")
        case .nil: buffer.append("nil")
        case .string(let string):
            let poundCount = rawStringPoundCount(for: string)
            let pounds = String(repeating: "#", count: poundCount)
            buffer.append(pounds)
            buffer.append("\"")
            buffer.append(escapeStringLiteral(string, poundCount: poundCount))
            buffer.append("\"")
            buffer.append(pounds)
        }
    }

    /// Escapes content for a Swift string literal, matching the token text
    /// `StringLiteralExprSyntax(content:)` produces.
    ///
    /// Mirrors SwiftSyntaxBuilder's own algorithm rather than the naive
    /// backslash-escaping of `"` and `\`: if `raw` contains an unescaped `"`
    /// or `\`, `StringLiteralExprSyntax(content:)` emits a *raw* string
    /// literal (`#"..."#`, with as many `#`s as needed to disambiguate) and
    /// leaves quotes/backslashes untouched inside it — only newlines and
    /// other unprintable ASCII control characters are backslash-escaped
    /// (prefixed by the same number of `#`s as the delimiter, per Swift's raw
    /// string escape syntax `\#n`). `emit(_:into:)` wraps this content with
    /// the matching opening/closing pound delimiters.
    ///
    /// - Parameter poundCount: The raw-string pound count already computed
    ///   for `raw` by the caller (via `rawStringPoundCount(for:)`), threaded
    ///   through rather than recomputed here so `raw` is scanned only once
    ///   per literal.
    static func escapeStringLiteral(_ raw: String, poundCount: Int) -> String {
        let delimiter = String(repeating: "#", count: poundCount)
        var out = ""
        out.reserveCapacity(raw.count)
        for scalar in raw.unicodeScalars {
            if let escape = controlCharacterEscape(for: scalar) {
                out.append("\\")
                out.append(delimiter)
                out.append(escape)
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    /// Returns the escape suffix (the text following `\` + delimiter) for a
    /// scalar that a single-line Swift string literal cannot contain
    /// unescaped, or `nil` if the scalar needs no escaping.
    ///
    /// Matches `StringLiteralExprSyntax`'s single-line escaping rules:
    /// newlines (including Unicode line/paragraph separators, which Swift's
    /// `Character.isNewline` also treats as newlines) and other unprintable
    /// ASCII control characters (including tab, since single-line literals —
    /// unlike multiline ones — must escape tab) are escaped; printable ASCII
    /// and non-ASCII scalars are left as-is.
    private static func controlCharacterEscape(for scalar: Unicode.Scalar) -> String? {
        let isPrintableASCII = scalar.value >= 0x20 && scalar.value < 0x7F
        let needsEscaping = Character(scalar).isNewline || (scalar.isASCII && !isPrintableASCII)
        guard needsEscaping else { return nil }
        switch scalar {
        case "\r": return "r"
        case "\n": return "n"
        case "\t": return "t"
        case "\0": return "0"
        default: return "u{\(String(scalar.value, radix: 16))}"
        }
    }

    /// Computes how many `#`s are needed to delimit `raw` as a raw string
    /// literal (`0` if `raw` contains no `"` or `\`, so an ordinary
    /// `"..."` literal suffices).
    ///
    /// Mirrors `StringLiteralExprSyntax.requiresEscaping`: scans `raw` for
    /// any `"` or `\`, and if found, returns one more than the longest run of
    /// consecutive `#` characters adjacent to a `"` or `\` — the minimal
    /// pound count that disambiguates the raw string's closing delimiter from
    /// any `#` sequence already present in the content.
    private static func rawStringPoundCount(for raw: String) -> Int {
        var countingPounds = false
        var consecutivePounds = 0
        var maxPounds = 0
        var requiresEscaping = false

        for character in raw {
            switch (countingPounds, character) {
            case (false, "\""), (false, "\\"):
                countingPounds = true
                requiresEscaping = true
            case (false, _):
                continue
            case (true, _) where character.unicodeScalars.contains("#"):
                consecutivePounds += 1
                maxPounds = max(maxPounds, consecutivePounds)
            case (true, "\""), (true, "\\"):
                continue
            case (true, _):
                countingPounds = false
                consecutivePounds = 0
            }
        }

        return requiresEscaping ? maxPounds + 1 : 0
    }
}
