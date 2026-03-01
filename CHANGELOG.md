# Changelog

All notable changes to MacroTemplateKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Bug Fixes

- Update Package@swift-6.0.swift swift-syntax range to 510..<700
- **lint**: Remove array_init rule and disable tags from tests
- **ci**: Use direct git-cliff installation instead of docker action
- **ci**: Use Xcode-bundled Swift instead of standalone toolchain

### Documentation

- Update changelog [skip ci]
- Update changelog [skip ci]

### Features

- Add isStatic, accessLevel, effects, and genericCall

### Miscellaneous Tasks

- Reduce to swift-tools-version 5.10, swift-syntax 510..<700
- Update swift-syntax dependency to from 509.0.0
- Update swift-syntax dependency to 602.0.0
- Add conventional commit validation workflow
- Add strict PR validation with Danger
- Add automatic changelog generation on main branch merges

## [0.0.1] - 2026-02-15

### Features

- Initial release of MacroTemplateKit v0.0.1

[Unreleased]: https://github.com/brunogama/MacroTemplateKit/compare/v0.0.1...HEAD

