#!/usr/bin/env bash
# Tell whether two versions of a workflow file differ only in `uses:` refs.
#
# Usage: pin_only.sh <old-file> <new-file>
#
# Exits 0 when the files are equal after dropping everything from the `@` of
# each `uses: <action>@<ref> # <comment>` line, 1 otherwise. Such a change is a
# SHA/tag pin bump that each derived MOD's Renovate applies on its own, and a
# drift run with GITHUB_TOKEN could not push it anyway (no `workflows`
# permission), so scaffold-drift.yml and merge.sh both leave it alone.

set -uo pipefail

old=${1:?usage: pin_only.sh <old-file> <new-file>}
new=${2:?usage: pin_only.sh <old-file> <new-file>}

normalize() {
  sed -E -e "s/^([[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*[\"']?[^@\"'[:space:]]+)@.*\$/\\1@/" "$1"
}

cmp -s <(normalize "$old") <(normalize "$new")
