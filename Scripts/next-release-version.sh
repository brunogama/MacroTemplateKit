#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -ne 0 ]]; then
  echo "error: next-release-version.sh does not accept arguments" >&2
  exit 2
fi

current_version="$(tr -d '[:space:]' < VERSION)"
if [[ ! "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: VERSION is not semantic: $current_version" >&2
  exit 1
fi

current_tag="v$current_version"
if ! git rev-parse --verify --quiet "refs/tags/$current_tag" >/dev/null; then
  echo "error: current release tag does not exist: $current_tag" >&2
  exit 1
fi

level=""
while IFS= read -r -d '' message; do
  message="${message#$'\n'}"
  subject="${message%%$'\n'*}"
  if [[ "$message" == *"[skip changelog]"* ]] ||
    grep -Eq '^chore\(release\)(!)?: ' <<<"$subject"; then
    continue
  fi
  if ! grep -Eq '^[a-z]+(\([^)]*\))?!?: ' <<<"$subject"; then
    continue
  fi

  if grep -Eq '^[a-z]+(\([^)]*\))?!: ' <<<"$subject" ||
    grep -Eq '^BREAKING[ -]CHANGE: ' <<<"$message"; then
    level="major"
    break
  fi
  if grep -Eq '^feat(\([^)]*\))?: ' <<<"$subject"; then
    level="minor"
  elif [[ -z "$level" ]]; then
    level="patch"
  fi
done < <(git log --format='%s%n%b%x00' "$current_tag..HEAD")

if [[ -z "$level" ]]; then
  echo "error: no releasable Conventional Commits exist after $current_tag" >&2
  exit 1
fi

IFS=. read -r major minor patch <<<"$current_version"
case "$level" in
major)
  major=$((10#$major + 1))
  minor=0
  patch=0
  ;;
minor)
  minor=$((10#$minor + 1))
  patch=0
  ;;
patch)
  patch=$((10#$patch + 1))
  ;;
esac

printf 'v%s.%s.%s\n' "$major" "$minor" "$patch"
