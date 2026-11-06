import MacroExamples
import SwiftSyntaxMacrosTestSupport
import XCTest

final class GeneratedAnswerMacroTests: XCTestCase {
  func testGeneratedConstructorDrivesMacroExpansion() {
    assertMacroExpansion(
      """
      let answer = #generatedAnswer
      """,
      expandedSource: """
        let answer = 42
        """,
      macros: ["generatedAnswer": GeneratedAnswerMacro.self]
    )
  }
}
