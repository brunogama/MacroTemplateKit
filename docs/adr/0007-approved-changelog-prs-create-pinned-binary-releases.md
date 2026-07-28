# Approved changelog PRs create pinned binary releases

**Status:** accepted

MacroTemplateKit releases are prepared and reviewed as pull requests. A release must not be
created from an unreviewed branch, and `main` must remain a source package for contributors.

## Decision

The changelog workflow calculates the next Semantic Version from Conventional Commits after the
current version recorded in `VERSION`:

- a breaking change increments the major version;
- a feature increments the minor version;
- other releasable changes increment the patch version.

Using `VERSION` as the base keeps version order monotonic even when old release tags are not in
first-parent order. `git-cliff` renders only the explicit `v<current>..HEAD` range into the new
section; existing reviewed changelog history is preserved.

Its automation PR contains one coherent release candidate:

- `VERSION` with the next version number and `RELEASE_BASE_VERSION` with the
  prerequisite published version;
- `RELEASE_DISTRIBUTION` switched from the bootstrap `source` state to `binary`,
  making metadata generation independent of fetched-tag depth;
- a changelog section generated for the corresponding `v<version>` tag;
- every Quick Start dependency example updated to that version;
- regenerated derived documentation such as `LLMS.txt`.

The release begins only after that automation PR has an approving review tied to its current head
commit and is merged. Stale approval of a force-updated candidate is not sufficient. Approval
without merge never creates a tag.

The release workflow builds and consumer-tests a universal macOS
`MacroTemplateKit.xcframework` for arm64 and x86_64. This binary contract is intentionally
pinned to Xcode 16.2, Swift 6.0, macOS 13 or later, and SwiftSyntax 600.0.1. It is not a
module-stable promise across arbitrary Swift or SwiftSyntax versions. Quick Start documentation
must state and use those exact compatibility versions.

The tag points to a detached release commit whose tree replaces the source manifests with a
binary `Package.swift` containing the final asset URL and checksum. Version-specific source
manifests are absent from that release tree so SwiftPM cannot bypass the binary manifest. The
source merge commit remains the head of `main`; release-only manifest changes never land there.

A GitHub release is staged with the XCFramework against a content-addressed temporary branch.
Immediately before publication, automation verifies that the immutable branch still identifies
the detached release commit. Publishing the staged release creates the tag only after the binary,
checksum, release manifest, release notes, and packaged-artifact consumer build have all passed.
Re-running an already published version verifies its parent candidate, tree shape, asset checksum,
and architectures rather than creating a second release. Candidate runs use per-PR concurrency and
wait for `RELEASE_BASE_VERSION` to exist as a remote tag, so distinct approved candidates cannot
publish out of version order without dropping queued pull-request events.

## Principles

- **Reviewed state is releasable state.** A tag must identify content that passed the repository's
  pull-request approval gate.
- **No placeholder releases.** Missing binaries, unresolved manifest placeholders, checksum
  mismatches, and consumer-build failures stop publication.
- **Compatibility is explicit.** A pinned binary is preferable to an unsupported claim of broad
  toolchain compatibility.
- **Development stays source-based.** Automation may construct a release tree, but it must not
  turn `main` into a binary-only package.

## Consequences

Binary consumers must use the documented Xcode/Swift/SwiftSyntax line. Supporting another line
requires a separately built and consumer-tested artifact contract; it is not inferred from the
source package's wider compatibility matrix.

Release automation needs permission to create releases, tags, and a temporary release branch.
The branch makes the detached binary-manifest commit available while the release remains a draft;
it is deleted after publication. The protected `main` branch is never pushed by the workflow.
