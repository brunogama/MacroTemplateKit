import Foundation

@main
enum ExpectedSyntaxGenMain {
  static func main() {
    let status = ExpectedSyntaxGenCommand.run(arguments: Array(CommandLine.arguments.dropFirst()))
    if status != 0 {
      exit(status)
    }
  }
}
