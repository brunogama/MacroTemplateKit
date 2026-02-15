/// Sum type representing literal values in templates.
///
/// This enum provides a type-safe representation of primitive literal values
/// that can be embedded in code generation templates. Each case corresponds
/// to a Swift literal type that can be rendered to SwiftSyntax AST nodes.
public enum LiteralValue: Equatable, Sendable, Hashable {
  /// Integer literal value (e.g., 42, -10, 0)
  case integer(Int)

  /// Double-precision floating-point literal (e.g., 3.14, -0.5, 1.0)
  case double(Double)

  /// String literal value (e.g., "hello", "", "multi\nline")
  case string(String)

  /// Boolean literal value (true or false)
  case boolean(Bool)

  /// Nil literal representing absence of value
  case `nil`
}
