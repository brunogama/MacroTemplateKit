import ExpectedSyntaxGenCore
import Foundation

public enum ExpectedSyntaxGenCommand {
  public static let help = """
    USAGE: ExpectedSyntaxGen [input] [--output <path>] [--kind <kind>] [--name <identifier>]

    Generate a Swift factory function that reconstructs syntax with public SwiftSyntax constructors.

    ARGUMENTS:
      input                     Input Swift file. Defaults to expected-output.swift. Use - for stdin.

    OPTIONS:
      -o, --output <path>       Output file. Defaults to expected-output-ast-syntax.swift beside input.
                                Use - for stdout. Stdin defaults to stdout.
      --kind <kind>             file, declaration, expression, or declarations. Default: file.
      --name <identifier>       Generated factory function name. Default: makeExpectedSyntax.
      -h, --help                Show this help.
    """

  @discardableResult
  public static func run(
    arguments: [String],
    readStandardInput: () throws -> Data = { try FileHandle.standardInput.readToEnd() ?? Data() },
    writeStandardOutput: (Data) throws -> Void = {
      try FileHandle.standardOutput.write(contentsOf: $0)
    },
    writeStandardError: (String) -> Void = { message in
      try? FileHandle.standardError.write(contentsOf: Data(message.utf8))
    }
  ) -> Int32 {
    do {
      let invocation = try parse(arguments: arguments)
      if invocation.showsHelp {
        try writeStandardOutput(Data((help + "\n").utf8))
        return 0
      }

      let paths = try resolvePaths(invocation)
      let inputData: Data
      if paths.input == "-" {
        inputData = try readStandardInput()
      } else {
        inputData = try Data(contentsOf: URL(fileURLWithPath: paths.input))
      }

      guard let source = String(data: inputData, encoding: .utf8) else {
        throw CommandFailure("input is not valid UTF-8")
      }

      let generated = try ExpectedSyntaxGenerator.generate(
        source: source,
        options: ExpectedSyntaxGenerationOptions(
          kind: invocation.kind,
          factoryName: invocation.factoryName
        )
      )
      let outputData = Data(generated.utf8)

      if paths.output == "-" {
        try writeStandardOutput(outputData)
      } else {
        try outputData.write(to: URL(fileURLWithPath: paths.output), options: .atomic)
      }
      return 0
    } catch let error as CommandUsageError {
      writeStandardError("error: \(error.message)\nRun 'ExpectedSyntaxGen --help' for usage.\n")
      return 2
    } catch let error as ExpectedSyntaxGenerationError {
      writeStandardError("error: \(error.description)\n")
      return 1
    } catch {
      writeStandardError("error: \(error.localizedDescription)\n")
      return 1
    }
  }

  private static func parse(arguments: [String]) throws -> Invocation {
    var invocation = Invocation()
    var index = 0
    var parsesOptions = true

    while index < arguments.count {
      let argument = arguments[index]
      if parsesOptions && argument == "--" {
        parsesOptions = false
      } else if parsesOptions && (argument == "--help" || argument == "-h") {
        invocation.showsHelp = true
      } else if parsesOptions && (argument == "--output" || argument == "-o") {
        invocation.outputPath = try value(after: argument, arguments: arguments, index: &index)
      } else if parsesOptions && argument.hasPrefix("--output=") {
        invocation.outputPath = try inlineValue(argument, prefix: "--output=")
      } else if parsesOptions && argument == "--kind" {
        let rawKind = try value(after: argument, arguments: arguments, index: &index)
        invocation.kind = try parseKind(rawKind)
      } else if parsesOptions && argument.hasPrefix("--kind=") {
        invocation.kind = try parseKind(inlineValue(argument, prefix: "--kind="))
      } else if parsesOptions && argument == "--name" {
        invocation.factoryName = try value(after: argument, arguments: arguments, index: &index)
      } else if parsesOptions && argument.hasPrefix("--name=") {
        invocation.factoryName = try inlineValue(argument, prefix: "--name=")
      } else if parsesOptions && argument.hasPrefix("-") && argument != "-" {
        throw CommandUsageError("unknown option '\(argument)'")
      } else if invocation.inputPath == nil {
        invocation.inputPath = argument
      } else {
        throw CommandUsageError("unexpected argument '\(argument)'")
      }
      index += 1
    }

    return invocation
  }

  private static func value(
    after option: String,
    arguments: [String],
    index: inout Int
  ) throws -> String {
    index += 1
    guard index < arguments.count, !knownOptions.contains(arguments[index]) else {
      throw CommandUsageError("missing value for \(option)")
    }
    return arguments[index]
  }

  private static func inlineValue(_ argument: String, prefix: String) throws -> String {
    let value = String(argument.dropFirst(prefix.count))
    guard !value.isEmpty else {
      throw CommandUsageError("missing value for \(prefix.dropLast())")
    }
    return value
  }

  private static let knownOptions: Set<String> = [
    "--", "--help", "-h", "--output", "-o", "--kind", "--name",
  ]

  private static func parseKind(_ value: String) throws -> ExpectedSyntaxOutputKind {
    switch value {
    case "file": return .sourceFile
    case "declaration", "decl": return .declaration
    case "expression", "expr": return .expression
    case "declarations", "decls": return .declarations
    default:
      throw CommandUsageError(
        "unknown kind '\(value)'; expected file, declaration, expression, or declarations"
      )
    }
  }

  private static func resolvePaths(_ invocation: Invocation) throws -> (
    input: String, output: String
  ) {
    let input = invocation.inputPath ?? "expected-output.swift"
    let output: String
    if let requestedOutput = invocation.outputPath {
      output = requestedOutput
    } else if input == "-" {
      output = "-"
    } else {
      let inputURL = URL(fileURLWithPath: input)
      let stem = inputURL.deletingPathExtension().lastPathComponent
      output =
        inputURL.deletingLastPathComponent()
        .appendingPathComponent("\(stem)-ast-syntax.swift")
        .path
    }

    if input != "-" && output != "-" {
      let inputURL = canonicalFileURL(input)
      let outputURL = canonicalFileURL(output)
      if inputURL == outputURL {
        throw CommandFailure("refusing to overwrite the input file '\(input)'")
      }
    }
    return (input, output)
  }

  private static func canonicalFileURL(_ path: String) -> URL {
    URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
  }
}

private struct Invocation {
  var inputPath: String?
  var outputPath: String?
  var kind: ExpectedSyntaxOutputKind = .sourceFile
  var factoryName = "makeExpectedSyntax"
  var showsHelp = false
}

private struct CommandUsageError: Error {
  let message: String

  init(_ message: String) {
    self.message = message
  }
}

private struct CommandFailure: Error, LocalizedError {
  let message: String

  init(_ message: String) {
    self.message = message
  }

  var errorDescription: String? { message }
}
