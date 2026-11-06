@_spi(RawSyntax) import SwiftSyntax

struct LayoutChild {
  let initializerLabel: String?
  let value: (any SyntaxProtocol)?
  let optionalValueType: SyntaxProtocol.Type?
}

private protocol OptionalSyntaxValue {
  var wrappedSyntax: (any SyntaxProtocol)? { get }
  var wrappedSyntaxType: SyntaxProtocol.Type { get }
}

extension Optional: OptionalSyntaxValue where Wrapped: SyntaxProtocol {
  fileprivate var wrappedSyntax: (any SyntaxProtocol)? {
    switch self {
    case .some(let value):
      return value
    case .none:
      return nil
    }
  }

  fileprivate var wrappedSyntaxType: SyntaxProtocol.Type { Wrapped.self }
}

enum SyntaxMetadataAdapter {
  static func layoutChildren<Node: SyntaxProtocol>(of node: Node) throws -> [LayoutChild] {
    guard case .layout(let keyPaths) = Node.structure else {
      throw ExpectedSyntaxGenerationError.unsupportedMetadata(
        "\(swiftTypeName(Node.self)) is not described as a layout node"
      )
    }

    return try keyPaths.map { keyPath in
      guard let label = childName(keyPath) else {
        throw ExpectedSyntaxGenerationError.unsupportedMetadata(
          "SwiftSyntax did not provide a constructor label for \(swiftTypeName(Node.self))"
        )
      }
      guard let typedKeyPath = keyPath as? PartialKeyPath<Node> else {
        throw ExpectedSyntaxGenerationError.unsupportedMetadata(
          "SwiftSyntax returned a key path with the wrong root type for \(swiftTypeName(Node.self)).\(label)"
        )
      }

      let rawValue: Any = node[keyPath: typedKeyPath]
      let value: (any SyntaxProtocol)?
      let optionalValueType: SyntaxProtocol.Type?
      if let optional = rawValue as? any OptionalSyntaxValue {
        value = optional.wrappedSyntax
        optionalValueType = optional.wrappedSyntaxType
      } else if let syntax = rawValue as? any SyntaxProtocol {
        value = syntax
        optionalValueType = nil
      } else {
        throw ExpectedSyntaxGenerationError.unsupportedMetadata(
          "\(swiftTypeName(Node.self)).\(label) is neither syntax nor optional syntax"
        )
      }

      return LayoutChild(
        initializerLabel: label.hasPrefix("unexpected") ? nil : label,
        value: value,
        optionalValueType: optionalValueType
      )
    }
  }
}

func swiftTypeName(_ type: Any.Type) -> String {
  String(reflecting: type)
}
