import SwiftSyntax

/// Thrown when the renderer produces source text that does not parse.
///
/// This always indicates a defect in MacroTemplateKit, never a recoverable
/// condition in the calling macro: a `Template`, `Statement`, or `Declaration`
/// value describes well-formed syntax by construction, so unparsable output
/// means the emitter got something wrong. There is nothing useful to do in a
/// `catch` block — the error exists to fail loudly, name the culprit, and carry
/// enough detail to file a bug.
///
/// It is deliberately not a `DiagnosticMessage`: conforming would pull
/// `SwiftSyntaxMacros` into this module, and the macro protocols'
/// `expansion(...)` methods already `throw`, so letting this propagate produces
/// a compiler diagnostic without any handling code.
///
/// Do not reach for `try!`. If this throws, the generated code is wrong and the
/// build should stop.
public struct RenderError: Error, CustomStringConvertible {
  /// What the renderer was asked to produce.
  public enum Kind: String, Sendable {
    case expression
    case statement
    case declaration
  }

  /// Which entry point failed.
  public let kind: Kind

  /// The source text the emitter produced, verbatim. This is the artefact to
  /// attach to a bug report.
  public let source: String

  /// The parse errors the compiler found in `source`.
  public let diagnostics: [String]

  public init(kind: Kind, source: String, diagnostics: [String]) {
    self.kind = kind
    self.source = source
    self.diagnostics = diagnostics
  }

  public var description: String {
    """
    MacroTemplateKit produced unparsable \(kind.rawValue) source. \
    This is a bug in MacroTemplateKit, not in your macro.

    Source:
    \(source)

    Parse errors:
    \(diagnostics.isEmpty ? "(none reported)" : diagnostics.joined(separator: "\n"))
    """
  }
}

extension RenderError {
  /// Builds an error from a node that failed to parse, collecting the parse
  /// diagnostics so the report names what actually went wrong.
  static func make(kind: Kind, source: String, node: some SyntaxProtocol) -> RenderError {
    RenderError(
      kind: kind,
      source: source,
      diagnostics: node.parseDiagnostics()
    )
  }
}

extension SyntaxProtocol {
  /// Describes the error nodes and missing tokens the parser left behind.
  fileprivate func parseDiagnostics() -> [String] {
    var found: [String] = []
    for node in DescendantSyntaxIterator(node: Syntax(self)) {
      if let unexpected = node.as(UnexpectedNodesSyntax.self) {
        found.append("unexpected source: \(unexpected.trimmedDescription)")
      }
    }
    return found
  }
}

/// Walks every descendant of a node, depth-first.
private struct DescendantSyntaxIterator: Sequence, IteratorProtocol {
  private var pending: [Syntax]

  init(node: Syntax) { pending = Array(node.children(viewMode: .all)) }

  mutating func next() -> Syntax? {
    guard let node = pending.popLast() else { return nil }
    pending.append(contentsOf: node.children(viewMode: .all))
    return node
  }
}
