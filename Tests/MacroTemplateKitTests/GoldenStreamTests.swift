import XCTest

@testable import MacroTemplateKit

/// Golden token streams for the whole corpus.
///
/// These replaced the legacy-vs-parsed parity tests when the structural
/// renderer was deleted. Be aware of what that trade cost: parity compared two
/// independent implementations, so a mistake in one showed up as a
/// disagreement. Goldens compare the renderer against *itself* at a point in
/// time. They catch regressions, but they cannot catch a wrong answer that has
/// always been wrong — and they will happily freeze a bug if one is
/// regenerated in.
///
/// So when a golden changes, read the diff and decide whether the new output is
/// correct Swift. Do not regenerate to make the suite green.
///
/// Trivia is excluded; only the token sequence is compared.
enum ParityGoldens {
  static let goldenTemplateStreams: [String] = [
    "42",
    "1.5",
    "# \" he said \"hi\"\\#nline2 \" #",
    "true",
    "nil",
    "newValue",
    "flag ? 1 : 2",
    "items . forEach ( { item in item . run ( ) } )",
    "print ( \" hi \" )",
    "date . timeIntervalSince ( start )",
    "a + b",
    "user . name",
    "0",
    "try load ( )",
    "await fetch ( )",
    "SQVField < String > ( \" name \" )",
    "[ 1 , 2 ]",
    "( 1 , \" a \" )",
    "[ \" k \" : 1 ]",
    "[ : ]",
    "array [ 0 ]",
    "dict [ \" k \" , default : 0 ]",
    "optional !",
    "\" prefix_ \\ ( name ) _suffix \"",
    "\" line1\\nline2_ \\ ( name ) _line3\\nline4 \"",
    "{ doWork ( ) }",
    "{ ( x : Int ) -> Int in return x }",
    "x = 1",
    "MyType . self",
    "a < b ? 1 : 2",
    "date . addingTimeInterval ( 1.0 ) . timeIntervalSince ( start )",
  ]
  static let goldenStatementStreams: [String] = [
    "x = 1",
    "return x",
    "break",
    "defer { cleanup ( ) }",
    "log ( )",
    "for item in items { item . run ( ) }",
    "guard let value = optionalValue else { return }",
    "guard flag else { return }",
    "if let value : Int = optionalValue { use ( value ) } else { fallback ( ) }",
    "if flag { onTrue ( ) } else { onFalse ( ) }",
    "let x : Int = 1",
    "switch value { case \" hello \" : break case 1 : break default : break }",
    "throw MyError ( )",
    "var y = 2",
  ]
  static let goldenDeclarationStreams: [String] = [
    "var _storage : [ String : Any ] = [ : ]",
    "var isValid : Bool { get { return true } set ( newValue ) { _valid = newValue } }",
    "enum Direction : String , CaseIterable { case north = \" north \" case point ( Int , Int ) }",
    "extension MyType : Equatable { let tag : String = \" x \" }",
    "func greet ( name : String ) -> String { return name }",
    "init ( value : Int ) { self . value = value }",
    "struct Point : Equatable { let x : Int let y : Int }",
    "typealias StringMap = [ String : String ]",
    "@ MainActor static func run ( with handler : @ escaping ( ) -> Void ) async throws { handler ( ) }",
    "struct Box < Element : Equatable , each Wrapped > : Equatable where Element : Hashable , Wrapped == Element { let value : Element }",
  ]
}

final class GoldenStreamTests: XCTestCase {

  func testTemplateGoldenStreams() throws {
    XCTAssertEqual(ParityCorpus.templates.count, ParityGoldens.goldenTemplateStreams.count)
    for (template, golden) in zip(ParityCorpus.templates, ParityGoldens.goldenTemplateStreams) {
      XCTAssertEqual(tokenStream(try Renderer.render(template)), golden)
    }
  }

  func testStatementGoldenStreams() throws {
    XCTAssertEqual(ParityCorpus.statements.count, ParityGoldens.goldenStatementStreams.count)
    for (statement, golden) in zip(ParityCorpus.statements, ParityGoldens.goldenStatementStreams) {
      XCTAssertEqual(tokenStream(try Renderer.render(statement)), golden)
    }
  }

  func testDeclarationGoldenStreams() throws {
    XCTAssertEqual(ParityCorpus.declarations.count, ParityGoldens.goldenDeclarationStreams.count)
    for (declaration, golden) in zip(ParityCorpus.declarations, ParityGoldens.goldenDeclarationStreams) {
      XCTAssertEqual(tokenStream(try Renderer.render(declaration)), golden)
    }
  }

  /// Every golden must be parsable Swift. A golden that only round-trips
  /// through this renderer is not evidence of anything.
  func testEveryCorpusEntryParsesCleanly() throws {
    for template in ParityCorpus.templates {
      XCTAssertFalse(try Renderer.render(template).hasError)
    }
    for statement in ParityCorpus.statements {
      XCTAssertFalse(try Renderer.render(statement).hasError)
    }
    for declaration in ParityCorpus.declarations {
      XCTAssertFalse(try Renderer.render(declaration).hasError)
    }
  }
}
