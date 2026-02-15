import Danger
import Foundation

let danger = Danger()

// MARK: - PR Validation

// Warn if PR is too large
let bigPRThreshold = 500
let additions = danger.github.pullRequest.additions ?? 0
let deletions = danger.github.pullRequest.deletions ?? 0
if additions + deletions > bigPRThreshold {
    warn("This PR is quite large. Consider breaking it into smaller, focused PRs.")
}

// Ensure PR has a description
if let body = danger.github.pullRequest.body, body.isEmpty {
    fail("Please provide a description for this PR.")
}

// Check for WIP
let title = danger.github.pullRequest.title
if title.contains("WIP") || title.contains("[WIP]") {
    warn("PR is marked as Work in Progress.")
}

// MARK: - File Validation

let editedFiles = danger.git.modifiedFiles + danger.git.createdFiles
let swiftFiles = editedFiles.filter { $0.hasSuffix(".swift") }

// Check for SwiftLint disable/enable tags - STRICTLY FORBIDDEN
for file in swiftFiles {
    guard let content = danger.utils.readFile(file) else { continue }

    let forbiddenPatterns = [
        "swiftlint:disable",
        "swiftlint:enable",
        "// swiftlint:disable",
        "// swiftlint:enable",
        "/* swiftlint:disable",
        "/* swiftlint:enable"
    ]

    for pattern in forbiddenPatterns {
        if content.contains(pattern) {
            fail("**\(file)** contains `\(pattern)`. SwiftLint disable/enable tags are strictly forbidden. Fix the underlying issue instead.")
        }
    }
}

// Check for force unwrapping in production code
for file in swiftFiles where !file.contains("Tests/") {
    guard let content = danger.utils.readFile(file) else { continue }

    // Simple heuristic: check for ! that's likely force unwrap
    let lines = content.components(separatedBy: "\n")
    for (index, line) in lines.enumerated() {
        // Skip comments
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
            continue
        }

        // Check for force unwrap patterns
        if line.contains("!.") || line.contains("!)") || line.contains("!,") || line.contains("! ") {
            warn("**\(file):\(index + 1)** may contain force unwrapping. Consider using optional binding.")
        }
    }
}

// Check for fatalError in production code
for file in swiftFiles where !file.contains("Tests/") {
    guard let content = danger.utils.readFile(file) else { continue }

    if content.contains("fatalError(") {
        fail("**\(file)** contains `fatalError()`. This is forbidden in production code.")
    }

    if content.contains("preconditionFailure(") {
        fail("**\(file)** contains `preconditionFailure()`. This is forbidden in production code.")
    }
}

// MARK: - Changelog

let hasChangelog = danger.git.modifiedFiles.contains("CHANGELOG.md") ||
                   danger.git.createdFiles.contains("CHANGELOG.md")

if !hasChangelog && swiftFiles.count > 0 {
    warn("Please update CHANGELOG.md with your changes.")
}

// MARK: - Tests

let hasTestChanges = swiftFiles.contains { $0.contains("Tests/") }
let hasSourceChanges = swiftFiles.contains { $0.contains("Sources/") && !$0.contains("Tests/") }

if hasSourceChanges && !hasTestChanges {
    warn("Source files were modified but no tests were added or updated. Consider adding tests.")
}

// MARK: - Documentation

let hasReadmeChanges = editedFiles.contains("README.md")
let hasPublicAPIChanges = swiftFiles.contains { file in
    guard let content = danger.utils.readFile(file) else { return false }
    return content.contains("public func") || content.contains("public var") ||
           content.contains("public struct") || content.contains("public enum") ||
           content.contains("public class") || content.contains("public protocol")
}

if hasPublicAPIChanges && !hasReadmeChanges {
    message("Public API changes detected. Consider updating documentation if needed.")
}

// MARK: - Summary

message("Reviewed \(swiftFiles.count) Swift file(s).")
