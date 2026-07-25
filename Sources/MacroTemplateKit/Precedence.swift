/// Swift's standard-library precedence groups, ordered loosest to tightest.
///
/// Only the groups reachable from `Template` are modelled. `atomic` is not a
/// real group: it stands for anything that binds tighter than every operator
/// (literals, identifiers, calls, subscripts, member access) and therefore
/// never needs parentheses.
enum Precedence: Int, Comparable, Sendable {
  case assignment = 1
  case ternary = 2
  case logicalDisjunction = 3
  case logicalConjunction = 4
  case comparison = 5
  case nilCoalescing = 6
  case casting = 7
  case rangeFormation = 8
  case addition = 9
  case multiplication = 10
  case bitwiseShift = 11
  case atomic = 100

  static func < (lhs: Precedence, rhs: Precedence) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  /// How operators of this group nest without parentheses.
  var associativity: Associativity {
    switch self {
    case .assignment, .ternary, .nilCoalescing: .right
    case .comparison, .rangeFormation, .casting: .none
    default: .left
    }
  }
}

enum Associativity: Sendable {
  case left
  case right
  /// Non-associative: `a < b < c` is not valid Swift, so equal-precedence
  /// nesting is parenthesized on both sides.
  case none
}

/// Maps operator text to its precedence group.
///
/// Unrecognised operators — including any custom operator a macro author
/// invents — return `nil`. Callers treat that as "parenthesize defensively":
/// redundant parentheses are noise, but a missing one silently changes what the
/// generated code means, so the failure is biased toward the harmless side.
func precedenceGroup(forOperator op: String) -> Precedence? {
  switch op {
  case "<<", ">>", "&<<", "&>>":
    .bitwiseShift
  case "*", "/", "%", "&*", "&":
    .multiplication
  case "+", "-", "&+", "&-", "|", "^":
    .addition
  case "..<", "...":
    .rangeFormation
  case "??":
    .nilCoalescing
  case "<", "<=", ">", ">=", "==", "!=", "===", "!==", "~=":
    .comparison
  case "&&":
    .logicalConjunction
  case "||":
    .logicalDisjunction
  case "=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<=", ">>=", "&&=", "||=", "??=":
    .assignment
  default:
    nil
  }
}

extension Template {
  /// The precedence at which this expression binds when nested inside another.
  ///
  /// Everything that is not an infix operator, cast, or ternary is `atomic`:
  /// a call, subscript, or member access already carries its own delimiters, so
  /// wrapping it in parentheses would only add noise.
  var precedence: Precedence {
    switch self {
    case .binaryOperation(_, let op, _):
      precedenceGroup(forOperator: op) ?? .assignment
    case .cast:
      .casting
    case .conditional:
      .ternary
    default:
      .atomic
    }
  }

  /// Whether this expression needs parentheses when it appears on `side` of a
  /// parent operator in `parent`.
  ///
  /// Looser-binding children always need them. Equal-binding children need them
  /// on the side the parent does *not* associate toward — `a - (b - c)` keeps
  /// its parentheses because `-` is left-associative, while `a - b - c` does
  /// not. Non-associative groups parenthesize on both sides.
  func needsParentheses(inside parent: Precedence, on side: Side) -> Bool {
    let child = precedence
    if child < parent { return true }
    guard child == parent else { return false }
    return switch parent.associativity {
    case .left: side == .right
    case .right: side == .left
    case .none: true
    }
  }

  enum Side: Sendable {
    case left
    case right
  }
}
