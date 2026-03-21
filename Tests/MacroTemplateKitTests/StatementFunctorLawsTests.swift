import XCTest

@testable import MacroTemplateKit

final class StatementFunctorLawsTests: XCTestCase {
  func testFunctorIdentityLaw_nestedStatementPreservesStructure() {
    let statement = makeNestedStatement()
    XCTAssertEqual(statement.map { $0 }, statement)
  }

  func testFunctorCompositionLaw_nestedStatementMatchesComposedMapping() {
    let statement = makeNestedStatement()
    let first: (Int) -> String = { "payload_\($0)" }
    let second: (String) -> Bool = { $0.hasSuffix("1") || $0.hasSuffix("8") }

    XCTAssertEqual(
      statement.map(first).map(second),
      statement.map { second(first($0)) }
    )
  }

  func testRewriteTemplates_identityTransformIsIdempotent() {
    let statement = makeNestedStatement()
    let rewritten = statement.rewriteTemplates { $0 }

    XCTAssertEqual(rewritten, statement)
    XCTAssertEqual(rewritten.rewriteTemplates { $0 }, rewritten)
  }

  func testRewriteStatements_identityTransformIsIdempotent() {
    let statement = makeNestedStatement()
    let rewritten = statement.rewriteStatements { $0 }

    XCTAssertEqual(rewritten, statement)
    XCTAssertEqual(rewritten.rewriteStatements { $0 }, rewritten)
  }

  func testCollectHelpersReturnPreOrderTemplateData() {
    let statement = makeNestedStatement()

    XCTAssertEqual(
      statement.collectVariables(),
      ["isReady", "source", "value", "mode", "matchesFast", "result", "defaultError", "error"]
    )
    XCTAssertEqual(statement.collectPayloads(), [1, 2, 3, 4, 5, 6, 7, 8])
    XCTAssertEqual(statement.foldStatements(into: 0) { count, _ in count += 1 }, 6)
  }
}

private func makeNestedStatement() -> Statement<Int> {
  .ifConditions(
    conditions: [
      .expression(.variable("isReady", payload: 1)),
      .optionalBinding(
        OptionalBindingCondition(
          name: "value",
          initializer: .variable("source", payload: 2)
        )
      ),
    ],
    thenBody: [
      .declaration(
        .property(
          PropertySignature(
            name: "cache",
            type: "Int",
            isStatic: false,
            isLet: false,
            initializer: .variable("value", payload: 3)
          )
        )
      ),
      .switchStatement(
        subject: .variable("mode", payload: 4),
        cases: [
          SwitchCase(
            items: [
              SwitchCaseItem(
                pattern: .memberAccess(base: nil, member: "fast"),
                whereCondition: .variable("matchesFast", payload: 5)
              )
            ],
            body: [
              .returnStatement(.variable("result", payload: 6))
            ]
          ),
          SwitchCase(
            pattern: .defaultCase,
            body: [
              .throwStatement(.variable("defaultError", payload: 7))
            ]
          ),
        ]
      ),
    ],
    elseBody: [
      .throwStatement(.variable("error", payload: 8))
    ]
  )
}
