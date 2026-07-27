import XCTest

@testable import MacroTemplateKit

/// Verifies `Statement.map` across every statement case in the parity corpus.
final class StatementFunctorLawsTests: XCTestCase {
  func testEveryStatementCaseSatisfiesIdentityLaw() {
    for (index, statement) in statementsWithPayloads().enumerated() {
      XCTAssertEqual(
        statement.map { $0 },
        statement,
        "Identity law failed for statement corpus entry \(index)"
      )
    }
  }

  func testEveryStatementCaseSatisfiesCompositionLaw() {
    let first: (Int) -> Int = { $0 + 1 }
    let second: (Int) -> String = { "payload-\($0)" }

    for (index, statement) in statementsWithPayloads().enumerated() {
      XCTAssertEqual(
        statement.map(first).map(second),
        statement.map { second(first($0)) },
        "Composition law failed for statement corpus entry \(index)"
      )
    }
  }

  func testMapVisitsPayloadsInSourceOrder() {
    let statement: Statement<Int> = .ifCase(
      pattern: .value(.variable("pattern", payload: 1)),
      value: .variable("subject", payload: 2),
      thenBody: [
        .ifStatement(
          condition: .variable("condition", payload: 3),
          thenBody: [
            .assignmentStatement(
              lhs: .variable("lhs", payload: 4),
              rhs: .variable("rhs", payload: 5)
            )
          ],
          elseBody: [.returnStatement(.variable("nestedElse", payload: 6))]
        )
      ],
      elseBody: [
        .guardCase(
          pattern: .value(.variable("elsePattern", payload: 7)),
          value: .variable("elseSubject", payload: 8),
          elseBody: [.throwStatement(.variable("error", payload: 9))]
        )
      ]
    )
    var visited: [Int] = []

    let mapped = statement.map { payload in
      visited.append(payload)
      return payload
    }

    XCTAssertEqual(mapped, statement)
    XCTAssertEqual(visited, Array(1...9))
  }

  private func statementsWithPayloads() -> [Statement<Int>] {
    ParityCorpus.statements.map { statement in
      statement.map { _ in 0 }
    }
  }
}
