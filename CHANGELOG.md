# Changelog

All notable changes to MacroTemplateKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Documentation

- Add copilot code review instructions
- Update changelog [skip ci]

### Miscellaneous Tasks

- Code review

## [0.0.5] - 2026-03-07

### Documentation

- Document binary package usage

### Features

- Improve dx for default template usage

### Miscellaneous Tasks

- Regenerate LLMS.txt [skip ci]

## [0.0.4] - 2026-03-01

### Bug Fixes

- **core**: Break up template map nil-coalescing chain for release builds
- Replace swift package generate-documentation with xcodebuild docbuild in docs workflow

### Documentation

- Update changelog [skip ci]
- Update changelog [skip ci]
- Update changelog [skip ci]
- Update changelog [skip ci]
- Sync README and DocC articles with latest API surface
- Update changelog [skip ci]
- Update changelog [skip ci]
- Update changelog [skip ci]
- Update changelog [skip ci]

### Features

- **core**: Add tupleLiteral, subscriptCall, forInStatement, ifLetBinding, enumDecl, typeAlias + relax SwiftLint thresholds
- **packaging**: Add binary manifest for MacroTemplateKit

### Miscellaneous Tasks

- Make commit lint reject push and pr
- Update MacroTemplateKit version to 0.0.3
- Modify changelog workflow branch configuration

### Refactor

- **tests**: Remove redundant swiftlint:disable tags now covered by Tests/.swiftlint.yml

## [.0.0.3] - 2026-03-01

### Bug Fixes

- **quick-10**: Add trailing commas to InheritedTypeListSyntax elements
- Update Package@swift-6.0.swift swift-syntax range to 510..<700
- **lint**: Remove array_init rule and disable tags from tests
- **ci**: Use direct git-cliff installation instead of docker action
- **ci**: Use Xcode-bundled Swift instead of standalone toolchain

### Documentation

- Update changelog [skip ci]
- Update changelog [skip ci]
- Update changelog [skip ci]
- Update changelog [skip ci]

### Features

- Add selfAccess, isFailable, isMutating, breakStatement
- **16-01**: Add new Template and Statement cases to MacroTemplateKit
- Add WhereRequirement support and fix rendering of commas and colons
- Add isStatic, accessLevel, effects, and genericCall

### Miscellaneous Tasks

- Reduce to swift-tools-version 5.10, swift-syntax 510..<700
- Update swift-syntax dependency to from 509.0.0
- Update swift-syntax dependency to 602.0.0
- Add conventional commit validation workflow
- Add strict PR validation with Danger
- Add automatic changelog generation on main branch merges

### Testing

- **16-01**: Add unit tests for all new Template and Statement cases

## [0.0.1] - 2026-02-15

### Features

- Initial release of MacroTemplateKit v0.0.1

[Unreleased]: https://github.com/brunogama/MacroTemplateKit/compare/v0.0.5...HEAD
[0.0.5]: https://github.com/brunogama/MacroTemplateKit/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/brunogama/MacroTemplateKit/compare/v.0.0.3...v0.0.4
[.0.0.3]: https://github.com/brunogama/MacroTemplateKit/compare/v0.0.1...v.0.0.3

