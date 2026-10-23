#!/usr/bin/env bash
# Tell whether two versions of a file differ only in the versions Renovate manages.
#
# Usage: pin_only.sh <old-file> <new-file> <path>
#
# <path> is the repo-relative name of both files and selects what counts as a
# managed version:
#   .github/workflows/*   the ref after the `@` of each `uses: <action>@<ref> # <comment>`
#   mise.toml, *.pkl      the tool and package versions listed in pins.pl
# Any other path has none, so the files never count as pin-only.
#
# Exits 0 when the files are equal once those versions are dropped, 1 otherwise.
# Such a change is a version bump that each derived MOD's Renovate applies on its
# own; for a workflow, a drift run with GITHUB_TOKEN could not push it anyway
# (no `workflows` permission). scaffold-drift.yml and merge.sh both leave it alone.

set -uo pipefail

old=${1:?usage: pin_only.sh <old-file> <new-file> <path>}
new=${2:?usage: pin_only.sh <old-file> <new-file> <path>}
path=${3:?usage: pin_only.sh <old-file> <new-file> <path>}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

case $path in
  .github/workflows/*)
    normalize() {
      sed -E -e "s/^([[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*[\"']?[^@\"'[:space:]]+)@.*\$/\\1@/" "$1"
    }
    ;;
  mise.toml | */mise.toml | *.pkl)
    normalize() { perl "$here/pins.pl" mask "$path" "$1"; }
    ;;
  *)
    exit 1
    ;;
esac

cmp -s <(normalize "$old") <(normalize "$new")
