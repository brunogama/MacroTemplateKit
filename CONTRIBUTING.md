# Contributing to MacroTemplateKit

Thank you for your interest in contributing to MacroTemplateKit! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## How to Contribute

### Reporting Issues

1. **Search existing issues** to avoid duplicates
2. **Use the issue template** when available
3. **Provide clear reproduction steps** for bugs
4. **Include environment details**: Swift version, OS, Xcode version

### Submitting Pull Requests

1. **Fork the repository** and create a feature branch from `main`
2. **Follow the coding standards** outlined below
3. **Write tests** for new functionality
4. **Update documentation** if needed
5. **Ensure all tests pass** before submitting

## Development Setup

### Prerequisites

- Swift 5.10+ (Swift 6.x recommended)
- Xcode 16+ (recommended)
- macOS 13+

### Bootstrap (Recommended)

Install the same tooling used in CI (SwiftLint, swift-format, Danger):

```bash
./scripts/bootstrap.sh
```

### Building

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/MacroTemplateKit.git
cd MacroTemplateKit

# Build the package
swift build

# Run tests
swift test
```

### Local CI (Run Before Pushing)

To avoid CI ping-pong, run the same checks CI runs for PRs:

```bash
./scripts/ci-local.sh
```

If you prefer running commands individually:

```bash
# Formatting (required on PRs)
swift-format lint --strict --recursive Sources/ Tests/

# Linting (required on PRs)
swiftlint lint --strict Sources/ Tests/

# Build with warnings treated as errors (required)
swift build -Xswiftc -warnings-as-errors

# Tests (required)
swift test --parallel
```

### Running Tests

```bash
# All tests
swift test

# Specific test
swift test --filter RendererTests

# With verbose output
swift test --verbose
```

## Coding Standards

### Swift Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use 2-space indentation
- Maximum line length: 100 characters
- Use meaningful variable and function names

### Documentation

- Add `///` documentation comments for all public APIs
- Include usage examples in documentation
- Update README for significant changes

### Commit Messages

This repository **enforces** [Conventional Commits](https://www.conventionalcommits.org/). All commits must follow this format or they will be **rejected by CI**.

You can validate commit messages locally (requires Node.js):

```bash
npm install --no-save @commitlint/cli @commitlint/config-conventional

# Validate the last commit message
git log -1 --pretty=format:'%s' | npx commitlint --verbose
```

**Format:**
```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

**Allowed types:**
| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, whitespace (no code change) |
| `refactor` | Code change that neither fixes nor adds |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `build` | Build system or dependencies |
| `ci` | CI configuration |
| `chore` | Other changes (no src/test modification) |
| `revert` | Reverts a previous commit |

**Rules:**
- Type must be lowercase
- Subject must be lowercase
- Subject must not be empty
- Header must be <= 100 characters
- No period at the end of subject

**Examples:**
```
feat: add new template case for dictionary literals
fix: correct rendering of empty array literals
docs: update installation instructions
test: add property-based tests for functor laws
refactor: extract helper methods in Renderer
ci: add commit message validation
feat(renderer): support method call expressions
fix(template): handle nil payload in conditional
```

**Invalid examples:**
```
Added new feature          # No type prefix
Feat: Add new feature      # Type must be lowercase
feat: Add new feature.     # Subject should be lowercase, no period
feat:missing space         # Space required after colon
```

### Code Quality Requirements

- **No compiler warnings**: Code must compile without warnings
- **No force unwrapping**: Avoid `!` in production code
- **Test coverage**: New features must include tests
- **Functor laws**: Any changes to `map` must preserve functor laws

## Architecture Guidelines

### Template Design

When adding new template cases:

1. Add the case to `Template<A>` enum
2. Implement `map` transformation in the functor extension
3. Add rendering logic to `Renderer`
4. Add `Equatable` and `Hashable` support
5. Write comprehensive tests

### Renderer Design

Rendering functions must be:

- **Pure**: No side effects
- **Total**: Handle all cases (exhaustive switch)
- **Deterministic**: Same input always produces same output

## Pull Request Process

1. **Create a feature branch**: `git checkout -b feature/your-feature`
2. **Make your changes** with appropriate tests
3. **Run the test suite**: `swift test`
4. **Push to your fork**: `git push origin feature/your-feature`
5. **Open a Pull Request** against `main`

### PR Requirements

- [ ] All tests pass
- [ ] No compiler warnings
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (for user-facing changes)
- [ ] Follows coding standards

## Release Process

Releases are managed by maintainers:

1. Update version in documentation
2. Update CHANGELOG.md
3. Create git tag: `git tag v0.0.6`
4. Push tag: `git push origin v0.0.6`
5. Create GitHub release

## Getting Help

- **Questions**: Open a GitHub Discussion
- **Bugs**: Open a GitHub Issue
- **Security**: Email maintainers directly (do not open public issues)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
