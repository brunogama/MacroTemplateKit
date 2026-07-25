/// A Swift pattern: the left-hand side of a `case` label, a `guard case`, or
/// an `if case`.
///
/// Patterns are not expressions. `case let .success(value)` cannot be built
/// from `Template` because `.success(value)` is a *destructuring* form — the
/// parentheses bind names rather than pass arguments — and `value` is a
/// binding site rather than a reference. Before this type existed the only way
/// to write one was to hand the whole thing to `Template.variable` as raw
/// source, which is what `AddAsyncMacro` does and what the `case-path`
/// benchmark did: correct output, but a string in the middle of a typed tree,
/// invisible to `map` and unchecked until the parse gate.
///
/// Bindings are written with `.bind`, and the emitter hoists a single `let`
/// in front of the whole pattern when any appear — `case let .success(value)`
/// rather than `case .success(let value)`. Both are valid Swift and mean the
/// same thing; the hoisted form is the one the standard library and the
/// CasePaths macros emit.
///
/// Named `MatchPattern` rather than `Pattern` because it only covers *match*
/// position — `case` labels, `guard case`, `if case` — not the binding
/// patterns in a function signature or a `let` declaration.
///
/// A bare `Pattern` also shadows out under `import XCTest`, which is how the
/// name first came up: the tests for this type would not compile. That is
/// narrower than it first looked, though — SwiftSyntax defines no bare
/// `Pattern`, only `PatternSyntaxEnum`, so a macro implementation importing
/// SwiftSyntax and SwiftSyntaxMacros would never have hit it. Test files
/// would. The accuracy argument is the one carrying the decision.
public indirect enum MatchPattern<A> {
  /// An enum case, optionally destructuring its associated values:
  /// `.success`, `.success(value)`, `.point(x, y)`.
  ///
  /// The leading dot is always emitted, so the enum type stays inferred from
  /// the matched value. A qualified pattern (`MyEnum.success`) is an
  /// expression pattern — use `.value` for that.
  case enumCase(String, [MatchPattern<A>] = [])

  /// A name bound by the match: the `value` in `case let .success(value)`.
  case bind(String)

  /// `_` — matches anything, binds nothing.
  case wildcard

  /// A tuple pattern: `(first, second)`.
  case tuple([MatchPattern<A>])

  /// An expression matched with `~=` rather than destructured: a literal, a
  /// range, or a qualified case like `MyEnum.success`.
  case value(Template<A>)

  /// Whether this pattern binds any name, and therefore needs a `let` in
  /// front of it. Checked once at the root by the emitter rather than
  /// distributing `let` to each binding site.
  var bindsAnyName: Bool {
    switch self {
    case .bind:
      true
    case .wildcard, .value:
      false
    case .enumCase(_, let subpatterns), .tuple(let subpatterns):
      subpatterns.contains(where: \.bindsAnyName)
    }
  }
}

// MARK: - Functor

extension MatchPattern {
  /// Maps a transformation over the payloads of embedded expression patterns.
  ///
  /// Mirrors `Template.map` and `Statement.map` so a pattern nested in a
  /// statement does not silently drop out of a `map` over the tree — the
  /// specific failure that raw-source patterns caused.
  public func map<B>(_ transform: (A) -> B) -> MatchPattern<B> {
    switch self {
    case .enumCase(let name, let subpatterns):
      .enumCase(name, subpatterns.map { $0.map(transform) })
    case .bind(let name):
      .bind(name)
    case .wildcard:
      .wildcard
    case .tuple(let subpatterns):
      .tuple(subpatterns.map { $0.map(transform) })
    case .value(let template):
      .value(template.map(transform))
    }
  }
}

// MARK: - Conformances

extension MatchPattern: Equatable where A: Equatable {}

extension MatchPattern: Hashable where A: Hashable {}

extension MatchPattern: Sendable where A: Sendable {}

// MARK: - Convenience

extension MatchPattern {
  /// `.caseName(_ :)` with one bound name — the overwhelmingly common shape
  /// in enum-driven macros.
  public static func enumCase(_ name: String, binding: String) -> MatchPattern<A> {
    .enumCase(name, [.bind(binding)])
  }
}
