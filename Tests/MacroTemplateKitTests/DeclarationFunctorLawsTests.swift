import XCTest

@testable import MacroTemplateKit

final class DeclarationFunctorLawsTests: XCTestCase {
  func testFunctorIdentityLaw_nestedDeclarationPreservesStructure() {
    let declaration = makeNestedDeclaration()
    XCTAssertEqual(declaration.map { $0 }, declaration)
  }

  func testFunctorCompositionLaw_nestedDeclarationMatchesComposedMapping() {
    let declaration = makeNestedDeclaration()
    let first: (Int) -> String = { "payload_\($0)" }
    let second: (String) -> Int = \.count

    XCTAssertEqual(
      declaration.map(first).map(second),
      declaration.map { second(first($0)) }
    )
  }

  func testRewriteDeclarations_identityTransformIsIdempotent() {
    let declaration = makeNestedDeclaration()
    let rewritten = declaration.rewriteDeclarations { $0 }

    XCTAssertEqual(rewritten, declaration)
    XCTAssertEqual(rewritten.rewriteDeclarations { $0 }, rewritten)
  }

  func testCollectHelpersReturnPreOrderTemplateDataAndDeclarationCount() {
    let declaration = makeNestedDeclaration()

    XCTAssertEqual(
      declaration.collectVariables(),
      ["identifierSource", "modeLabel", "isEnabled", "enabledName", "fallbackName"]
    )
    XCTAssertEqual(declaration.collectPayloads(), [1, 2, 3, 4, 5])
    XCTAssertEqual(declaration.foldDeclarations(into: 0) { count, _ in count += 1 }, 5)
  }
}

private func makeNestedDeclaration() -> Declaration<Int> {
  .structDecl(
    StructSignature(
      name: "Feature",
      members: [
        .property(
          PropertySignature(
            name: "identifier",
            type: "String",
            initializer: .variable("identifierSource", payload: 1)
          )
        ),
        .enumDecl(
          EnumSignature(
            name: "Mode",
            cases: [
              EnumCaseSignature(name: "fast"),
              EnumCaseSignature(name: "safe"),
            ],
            members: [
              .computedProperty(
                ComputedPropertySignature(
                  name: "label",
                  type: "String",
                  getter: [
                    .returnStatement(.variable("modeLabel", payload: 2))
                  ]
                )
              )
            ]
          )
        ),
        .function(
          FunctionSignature(
            name: "render",
            returnType: "String",
            body: [
              .ifConditions(
                conditions: [
                  .expression(.variable("isEnabled", payload: 3))
                ],
                thenBody: [
                  .returnStatement(.variable("enabledName", payload: 4))
                ],
                elseBody: [
                  .returnStatement(.variable("fallbackName", payload: 5))
                ]
              )
            ]
          )
        ),
      ]
    )
  )
}
