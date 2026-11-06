import SwiftParser
import SwiftSyntax

/// The SwiftSyntax value returned by the generated factory function.
public enum ExpectedSyntaxOutputKind: String, CaseIterable, Sendable {
  case sourceFile = "file"
  case declaration
  case expression
  case declarations
}

/// Options that define the generated factory function.
public struct ExpectedSyntaxGenerationOptions: Equatable, Sendable {
  public var kind: ExpectedSyntaxOutputKind
  public var factoryName: String

  public init(
    kind: ExpectedSyntaxOutputKind = .sourceFile,
    factoryName: String = "makeExpectedSyntax"
  ) {
    self.kind = kind
    self.factoryName = factoryName
  }
}

/// A parser diagnostic detached from SwiftParser's transport types.
public struct ExpectedSyntaxDiagnostic: Equatable, Sendable {
  public let message: String
  public let line: Int
  public let column: Int

  public init(message: String, line: Int, column: Int) {
    self.message = message
    self.line = line
    self.column = column
  }
}

/// Failures detected before constructor source is returned.
public enum ExpectedSyntaxGenerationError: Error, Equatable, Sendable {
  case invalidFactoryName(String)
  case malformedSource([ExpectedSyntaxDiagnostic])
  case rootMismatch(expected: ExpectedSyntaxOutputKind, detail: String)
  case unrepresentableFragment(String)
  case unsupportedMetadata(String)
}

extension ExpectedSyntaxGenerationError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .invalidFactoryName(let name):
      return "Invalid Swift factory function name: \(name)"
    case .malformedSource(let diagnostics):
      let details = diagnostics.map { diagnostic in
        "\(diagnostic.line):\(diagnostic.column): \(diagnostic.message)"
      }
      return "Input is not valid Swift:\n\(details.joined(separator: "\n"))"
    case .rootMismatch(let expected, let detail):
      return "Input does not contain one \(expected.displayName): \(detail)"
    case .unrepresentableFragment(let detail):
      return "The selected fragment kind cannot preserve the input: \(detail)"
    case .unsupportedMetadata(let detail):
      return "The resolved SwiftSyntax metadata cannot be emitted safely: \(detail)"
    }
  }
}

/// Generates Swift source that reconstructs parsed syntax with public SwiftSyntax constructors.
public enum ExpectedSyntaxGenerator {
  public static func generate(
    source: String,
    options: ExpectedSyntaxGenerationOptions = ExpectedSyntaxGenerationOptions()
  ) throws -> String {
    guard options.factoryName.isValidSwiftIdentifier(for: .variableName),
      options.factoryName.unescapedIdentifier != "SwiftSyntax"
    else {
      throw ExpectedSyntaxGenerationError.invalidFactoryName(options.factoryName)
    }

    let root = try ExpectedSyntaxInputParser.parse(source: source, kind: options.kind)
    var emitter = ConstructorEmitter()
    return try emitter.render(root: root, factoryName: options.factoryName)
  }
}

extension String {
  fileprivate var unescapedIdentifier: String {
    guard first == "`", last == "`" else { return self }
    return String(dropFirst().dropLast())
  }
}

extension ExpectedSyntaxOutputKind {
  fileprivate var displayName: String {
    switch self {
    case .sourceFile:
      return "source file"
    case .declaration:
      return "declaration"
    case .expression:
      return "expression"
    case .declarations:
      return "declaration list"
    }
  }
}
