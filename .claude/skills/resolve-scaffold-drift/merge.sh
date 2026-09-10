#!/usr/bin/env bash
# Three-way merge of scaffold-tracked files into the current derived MOD.
#
# Usage: merge.sh <scaffold-clone-dir> <baseline-sha>
#
#   <scaffold-clone-dir>  a clone of factorio-mod-scaffold, checked out at the
#                         tip of its default branch (this is "theirs")
#   <baseline-sha>        the scaffold commit the MOD was last synced to, from
#                         .scaffold-sync.json ".commit" (this is the merge base)
#
# Run from the derived MOD's repo root ("ours"). Applies clean results to the
# working tree (writing files, `git add -f`, `git rm -f`) and prints one line per
# path. `-f` because a mid-rollout MOD may still have a stale .gitignore that
# excludes .claude/ -- every path here is a designated tracked path.
#
#   CLEAN <path>     three-way merge applied, no conflict
#   CREATE <path>    file added from the scaffold
#   DELETE <path>    file removed to follow the scaffold
#   CONFLICT <path>  conflict markers written; needs a human / Claude decision
#   SKIP <path>      no change (identical, scaffold untouched since the baseline,
#                    a deletion the MOD made on purpose, or a symlink we refuse
#                    to touch)
#   ERROR <path>     merge.sh could not process the path (e.g. `git merge-file`
#                    hard error); the caller must stop and report, not commit
#
# Exits 0 even when CONFLICT lines are printed. Exits 2 on a usage/setup error.
# Does NOT edit .scaffold-sync.json, does NOT commit, and does NOT touch the
# Lua-testing fragments inside mise.toml / .github/renovate.json -- the caller
# handles those.

set -uo pipefail

if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  echo "merge.sh: needs bash >= 4 (found ${BASH_VERSION:-unknown}); on macOS install one via Homebrew etc." >&2
  exit 2
fi

scaffold=${1:?usage: merge.sh <scaffold-clone-dir> <baseline-sha>}
base=${2:?usage: merge.sh <scaffold-clone-dir> <baseline-sha>}

paths_file="$scaffold/.scaffold-sync.paths"
[ -r "$paths_file" ] || { echo "merge.sh: cannot read $paths_file" >&2; exit 2; }
git -C "$scaffold" rev-parse --verify --quiet "$base^{commit}" >/dev/null \
  || { echo "merge.sh: $base is not a commit in $scaffold" >&2; exit 2; }

theirs_ref=HEAD  # the scaffold clone sits at the tip of its default branch

# --- collect candidate paths ---------------------------------------------------
# Union of the tracked files that match each entry, on the scaffold side and ours.
declare -A seen=()
while IFS= read -r entry || [ -n "$entry" ]; do
  entry="${entry%%#*}"                       # strip trailing comment
  entry="$(printf '%s' "$entry" | tr -d '[:space:]')"
  [ -n "$entry" ] || continue
  while IFS= read -r f; do [ -n "$f" ] && seen["$f"]=1; done \
    < <(git -C "$scaffold" ls-tree -r --name-only "$theirs_ref" -- "$entry" 2>/dev/null)
  while IFS= read -r f; do [ -n "$f" ] && seen["$f"]=1; done \
    < <(git ls-files -- "$entry" 2>/dev/null)
done < "$paths_file"

# --- test-lane auto-detection ------------------------------------------------
# No .busted in the MOD -> it has dropped the test lane; never resurrect these.
if [ ! -e .busted ]; then
  # shellcheck disable=SC2034  # $p is expanded by `unset` itself; the single
  # quotes only keep the subscript from being treated as a glob.
  for p in .github/workflows/ci.yml .busted tasks/test spec/helper.lua; do
    unset 'seen[$p]'
  done
fi

# --- per-path three-way merge ----------------------------------------------
status() { printf '%s %s\n' "$1" "$2"; }

for path in $(printf '%s\n' "${!seen[@]}" | LC_ALL=C sort); do
  tmp=$(mktemp -d)
  b="$tmp/base"; t="$tmp/theirs"; o="$tmp/ours"
  hb=0; ht=0; ho=0

  # Scaffold-side mode for this path (empty if it exists only in ours).
  mode=$(git -C "$scaffold" ls-tree "$theirs_ref" -- "$path" | awk '{print $1}')
  if [ "$mode" = "120000" ]; then
    echo "merge.sh: skipping symlink $path" >&2
    status SKIP "$path"
    rm -rf "$tmp"
    continue
  fi

  if git -C "$scaffold" cat-file -e "$base:$path" 2>/dev/null; then
    git -C "$scaffold" show "$base:$path" > "$b"; hb=1
  fi
  if git -C "$scaffold" cat-file -e "$theirs_ref:$path" 2>/dev/null; then
    git -C "$scaffold" show "$theirs_ref:$path" > "$t"; ht=1
  fi
  if [ -f "$path" ]; then cp "$path" "$o"; ho=1; fi

  if [ $ht -eq 1 ] && [ $ho -eq 0 ]; then
    if [ $hb -eq 1 ] && cmp -s "$b" "$t"; then
      status SKIP "$path"                       # MOD deleted it, scaffold unchanged
    elif [ $hb -eq 1 ]; then
      status CONFLICT "$path"                   # MOD deleted, scaffold changed
    else
      mkdir -p "$(dirname "$path")"
      cp "$t" "$path"
      [ "$mode" = "100755" ] && chmod +x "$path"
      git add -f -- "$path"
      status CREATE "$path"
    fi
  elif [ $ht -eq 0 ] && [ $ho -eq 1 ]; then
    if [ $hb -eq 1 ] && cmp -s "$b" "$o"; then
      if git rm -q -f -- "$path"; then status DELETE "$path"; else status SKIP "$path"; fi
    elif [ $hb -eq 1 ]; then
      status CONFLICT "$path"                   # scaffold deleted, MOD modified
    else
      status SKIP "$path"                       # exists only in ours
    fi
  elif [ $ht -eq 1 ] && [ $ho -eq 1 ]; then
    if cmp -s "$t" "$o"; then
      status SKIP "$path"                       # already identical
    elif [ $hb -eq 1 ] && cmp -s "$b" "$t"; then
      status SKIP "$path"                       # scaffold untouched since baseline
    else
      base_arg="$b"
      [ $hb -eq 1 ] || { : > "$tmp/empty"; base_arg="$tmp/empty"; }
      # Capture the exit code as a plain statement: `$?` right after an `if`
      # would reflect the `if` condition, not `git merge-file`. rc is 0 on a
      # clean merge, 1..127 for that many conflict regions, >=128 on a hard
      # error (I/O, binary input) -- which we must not stage.
      git merge-file -L ours -L base -L theirs --diff3 -p \
        "$o" "$base_arg" "$t" > "$tmp/out" 2>/dev/null
      rc=$?
      if [ "$rc" -eq 0 ]; then
        cp "$tmp/out" "$path"; git add -f -- "$path"
        status CLEAN "$path"
      elif [ "$rc" -lt 128 ] && [ -s "$tmp/out" ]; then
        cp "$tmp/out" "$path"; git add -f -- "$path"
        status CONFLICT "$path"
      else
        status ERROR "$path"
      fi
    fi
  fi
  rm -rf "$tmp"
done
