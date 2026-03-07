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
      Template<Void>.variable("api")
        .method("fetch") {
          TemplateArgument<Void>.unlabeled(.variable("request"))
        }
        .tryAwait()
    )

    XCTAssertEqual(normalized(expression.description), normalized("try await api.fetch(request)"))
  }

  func testDoccStatementExampleRendersExpectedCode() {
    let statement: CodeBlockItemSyntax = Renderer.render(
      Statement<Void>.letBinding(
        name: "result",
        type: nil,
        initializer: Template<Void>.variable("api")
          .method("fetch") {
            TemplateArgument<Void>.unlabeled(.variable("request"))
          }
      )
    )

    XCTAssertEqual(normalized(statement.description), normalized("let result = api.fetch(request)"))
  }

  func testReadmeGenericDeclarationExampleRendersExpectedCode() {
    let declaration: DeclSyntax = Renderer.render(
      Declaration<Void>.function(
        FunctionSignature(
          accessLevel: .public,
          attributes: [.mainActor],
          name: "register",
          genericParameters: [
            GenericParameterSignature(name: "Service", constraint: "Sendable"),
            GenericParameterSignature(name: "Dependency", isParameterPack: true),
          ],
          parameters: [
            ParameterSignature(label: "_", name: "service", type: "Service"),
            ParameterSignature(name: "dependencies", type: "repeat each Dependency"),
            ParameterSignature(
              name: "handler",
              type: "() -> Void",
              attributes: [.escaping]
            ),
          ],
          whereRequirements: [
            .sameType("Service.ID", "String"),
            .conformance("each Dependency", "Sendable"),
          ],
          body: []
        )
      )
    )

    let rendered = normalized(declaration.formatted().description)
    XCTAssertTrue(rendered.contains(normalized("@MainActor public func register")))
    XCTAssertTrue(rendered.contains(normalized("<Service: Sendable, each Dependency>")))
    XCTAssertTrue(rendered.contains(normalized("_ service: Service")))
    XCTAssertTrue(rendered.contains(normalized("dependencies: repeat each Dependency")))
    XCTAssertTrue(rendered.contains(normalized("handler: @escaping () -> Void")))
    XCTAssertTrue(
      rendered.contains(normalized("where Service.ID == String, each Dependency: Sendable"))
    )
  }

  func testDoccClosureAttributeExampleRendersExpectedCode() {
    let expression: ExprSyntax = Renderer.render(
      Template<Void>.closure(
        attributes: [.sendable],
        params: [(name: "value", type: "Int")],
        returnType: "Void",
        body: [
          .expression(
            .call(
              "handle",
              arguments: [
                .unlabeled(.variable("value"))
              ]
            )
          )
        ]
      )
    )

    let rendered = normalized(expression.description)
    XCTAssertTrue(rendered.contains(normalized("@Sendable")))
    XCTAssertTrue(rendered.contains(normalized("value")))
    XCTAssertTrue(rendered.contains(normalized("Int")))
    XCTAssertTrue(rendered.contains(normalized("Void")))
    XCTAssertTrue(rendered.contains(normalized("handle(value)")))
  }

  func testExamplesEscapingParameterExampleRendersExpectedCode() {
    let declaration: DeclSyntax = Renderer.render(
      Declaration<Void>.function(
        FunctionSignature(
          name: "install",
          parameters: [
            ParameterSignature(
              name: "completionHandler",
              type: "(User) -> Void",
              attributes: [.escaping]
            )
          ],
          body: []
        )
      )
    )

    XCTAssertTrue(
      normalized(declaration.formatted().description)
        .contains(normalized("completionHandler: @escaping (User) -> Void"))
    )
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
              initializer: Template<Void>.variable("api")
                .method("fetch") {
                  TemplateArgument<Void>.labeled("id", .variable("id"))
                }
                .tryAwait()
            ),
            .returnStatement(
              .call(
                "User",
                arguments: [
                  .labeled("from", .variable("data"))
                ]
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
