import Foundation
import XCTest

@testable import ExpectedSyntaxGenCLI

final class ExpectedSyntaxGenCommandTests: XCTestCase {
  func testHelpWritesToStandardOutput() throws {
    var output = Data()
    var errorOutput = ""

    let status = ExpectedSyntaxGenCommand.run(
      arguments: ["--help"],
      readStandardInput: { Data() },
      writeStandardOutput: { output.append($0) },
      writeStandardError: { errorOutput += $0 }
    )

    XCTAssertEqual(status, 0)
    let outputText = try XCTUnwrap(String(data: output, encoding: .utf8))
    XCTAssertTrue(outputText.contains("USAGE:"))
    XCTAssertEqual(errorOutput, "")
  }

  func testStandardInputToStandardOutput() throws {
    var output = Data()
    var errorOutput = ""

    let status = ExpectedSyntaxGenCommand.run(
      arguments: ["-", "--output", "-", "--kind", "expression", "--name", "makeValue"],
      readStandardInput: { Data("value + 1".utf8) },
      writeStandardOutput: { output.append($0) },
      writeStandardError: { errorOutput += $0 }
    )

    XCTAssertEqual(status, 0)
    let outputText = try XCTUnwrap(String(data: output, encoding: .utf8))
    XCTAssertTrue(outputText.contains("public func makeValue()"))
    XCTAssertEqual(errorOutput, "")
  }

  func testInvalidUTF8FailsWithoutOutput() {
    var output = Data()
    var errorOutput = ""

    let status = ExpectedSyntaxGenCommand.run(
      arguments: ["-", "--output", "-"],
      readStandardInput: { Data([0xFF, 0xFE]) },
      writeStandardOutput: { output.append($0) },
      writeStandardError: { errorOutput += $0 }
    )

    XCTAssertEqual(status, 1)
    XCTAssertTrue(output.isEmpty)
    XCTAssertTrue(errorOutput.contains("valid UTF-8"))
  }

  func testUnknownOptionIsAUsageError() {
    var errorOutput = ""
    let status = ExpectedSyntaxGenCommand.run(
      arguments: ["--unknown"],
      readStandardInput: { Data() },
      writeStandardOutput: { _ in },
      writeStandardError: { errorOutput += $0 }
    )

    XCTAssertEqual(status, 2)
    XCTAssertTrue(errorOutput.contains("unknown option"))
  }

  func testKnownOptionCannotBeConsumedAsAnotherOptionsValue() {
    var errorOutput = ""
    let status = ExpectedSyntaxGenCommand.run(
      arguments: ["--output", "--kind", "expression"],
      readStandardInput: { Data() },
      writeStandardOutput: { _ in },
      writeStandardError: { errorOutput += $0 }
    )

    XCTAssertEqual(status, 2)
    XCTAssertTrue(errorOutput.contains("missing value for --output"))
  }

  func testEmptyInlineOptionValueIsAUsageError() {
    var errorOutput = ""
    let status = ExpectedSyntaxGenCommand.run(
      arguments: ["--output="],
      readStandardInput: { Data() },
      writeStandardOutput: { _ in },
      writeStandardError: { errorOutput += $0 }
    )

    XCTAssertEqual(status, 2)
    XCTAssertTrue(errorOutput.contains("missing value for --output"))
  }

  func testSameInputAndOutputPathIsRejectedBeforeWriting() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ExpectedSyntaxGenCommandTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let input = directory.appendingPathComponent("input.swift")
    try Data("let value = 1\n".utf8).write(to: input)
    var errorOutput = ""

    let status = ExpectedSyntaxGenCommand.run(
      arguments: [input.path, "--output", input.path],
      readStandardInput: { Data() },
      writeStandardOutput: { _ in },
      writeStandardError: { errorOutput += $0 }
    )

    XCTAssertEqual(status, 1)
    XCTAssertTrue(errorOutput.contains("refusing to overwrite"))
    XCTAssertEqual(try String(contentsOf: input, encoding: .utf8), "let value = 1\n")
  }

  func testDefaultOutputIsWrittenBesideInputAfterValidation() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ExpectedSyntaxGenCommandTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let input = directory.appendingPathComponent("custom.swift")
    let output = directory.appendingPathComponent("custom-ast-syntax.swift")
    try Data("let value = 1\n".utf8).write(to: input)

    let status = ExpectedSyntaxGenCommand.run(
      arguments: [input.path],
      readStandardInput: { Data() },
      writeStandardOutput: { _ in },
      writeStandardError: { _ in }
    )

    XCTAssertEqual(status, 0)
    XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
    let generated = try String(contentsOf: output, encoding: .utf8)
    XCTAssertTrue(generated.contains("public func makeExpectedSyntax()"))
  }

  func testMalformedInputDoesNotReplaceExistingOutput() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ExpectedSyntaxGenCommandTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let input = directory.appendingPathComponent("input.swift")
    let output = directory.appendingPathComponent("output.swift")
    try Data("func broken(".utf8).write(to: input)
    try Data("sentinel".utf8).write(to: output)

    let status = ExpectedSyntaxGenCommand.run(
      arguments: [input.path, "--output", output.path],
      readStandardInput: { Data() },
      writeStandardOutput: { _ in },
      writeStandardError: { _ in }
    )

    XCTAssertEqual(status, 1)
    XCTAssertEqual(try String(contentsOf: output, encoding: .utf8), "sentinel")
  }
}
