import MacroTemplateKit
import SwiftSyntax
import XCTest

final class PublicExamplesTests: XCTestCase {

  private func normalized(_ string: String) -> String {
    string.filter { !$0.isWhitespace && !$0.isNewline }
  }

  func testVoidVariableConvenienceMatchesExplicitPayload() {
    let template = Template<Void>.variable("name")
    guard case .variable("name", _) = template else {
      return XCTFail("Expected variable convenience to create a variable template")
    }
  }

  func testVoidPropertyConvenienceMatchesExplicitPayload() {
    let template = Template<Void>.property("count", on: "storage")
    guard case .propertyAccess(let base, "count") = template,
      case .variable("storage", _) = base
    else {
      return XCTFail("Expected property convenience to create a property access on a variable")
    }
  }

  func testReadmeExpressionExampleRendersExpectedCode() {
    let expression: ExprSyntax = Renderer.render(
      Template<Void>.tryAwait(
        .methodCall(
          base: .variable("api"),
          method: "fetch",
          arguments: [(label: nil, value: .variable("request"))]
        )
      )
    )

    XCTAssertEqual(normalized(expression.description), normalized("try await api.fetch(request)"))
  }

  func testDoccStatementExampleRendersExpectedCode() {
    let statement: CodeBlockItemSyntax = Renderer.render(
      Statement<Void>.letBinding(
        name: "result",
        type: nil,
        initializer: .methodCall(
          base: .variable("api"),
          method: "fetch",
          arguments: [(label: nil, value: .variable("request"))]
        )
      )
    )

    XCTAssertEqual(normalized(statement.description), normalized("let result = api.fetch(request)"))
  }

  func testExamplesStyleDeclarationRendersExpectedCode() {
    let declaration: DeclSyntax = Renderer.render(
      Declaration<Void>.function(
        FunctionSignature(
          accessLevel: .public,
          name: "loadUser",
          parameters: [ParameterSignature(label: "with", name: "id", type: "String")],
          isAsync: true,
          canThrow: true,
          returnType: "User",
          body: [
            .letBinding(
              name: "data",
              type: nil,
              initializer: .tryAwait(
                .methodCall(
                  base: .variable("api"),
                  method: "fetch",
                  arguments: [(label: "id", value: .variable("id"))]
                )
              )
            ),
            .returnStatement(
              .functionCall(
                function: "User",
                arguments: [(label: "from", value: .variable("data"))]
              )
            ),
          ]
        )
      )
    )

    XCTAssertEqual(
      normalized(declaration.description),
      normalized(
        """
        public func loadUser(with id: String) async throws -> User {
            let data = try await api.fetch(id: id)
            return User(from: data)
        }
        """
      )
    )
  }
}
