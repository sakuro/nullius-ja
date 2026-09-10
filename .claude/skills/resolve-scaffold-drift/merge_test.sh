#!/usr/bin/env bash
# Fixture test for merge.sh. Builds a scaffold repo (with a baseline commit and a
# newer HEAD) and a derived-MOD repo, runs merge.sh, and asserts the status lines
# and resulting file contents.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
merge=$here/merge.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail=0
check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    echo "ok   - $1"
  else
    echo "FAIL - $1"
    echo "       expected: $2"
    echo "       actual:   $3"
    fail=1
  fi
}

git_quiet() { git -c init.defaultBranch=main -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }

# --- build the scaffold repo ------------------------------------------------
scaffold=$work/scaffold
mkdir -p "$scaffold"/.claude/skills/resolve-scaffold-drift "$scaffold"/tasks
cd "$scaffold" || exit 1
git_quiet init
# a small deterministic path list for the fixture (not the real one).
# All four test-lane entries merge.sh drops for a no-.busted MOD are listed so
# the "test lane disabled" assertions below exercise every one of them.
cat > .scaffold-sync.paths <<'EOF'
verbatim.txt
mergeable.txt
gone.txt
newfile.txt
tasks/build
tasks/newexec
LINK.md
bin.dat
.busted
.github/workflows/ci.yml
tasks/test
spec/helper.lua
EOF
printf 'v1\n'            > verbatim.txt
printf 'a\nb\nc\nd\ne\n' > mergeable.txt
printf 'delete me\n'     > gone.txt
mkdir -p tasks .github/workflows spec
printf 'build v1\n'      > tasks/build
printf 'busted\n'        > .busted
printf 'ci v1\n'         > .github/workflows/ci.yml
printf 'test\n'          > tasks/test
printf '\n'              > spec/helper.lua
printf 'agents\n'        > AGENTS.md          # symlink target for LINK.md
ln -s AGENTS.md LINK.md                       # tracked symlink -> merge.sh must SKIP
printf 'AAAA\n'          > bin.dat            # theirs turns this into NUL bytes -> merge-file hard error
git_quiet add -A
git_quiet commit -m ":seedling: base"
base=$(git rev-parse HEAD)

printf 'v2\n'            > verbatim.txt         # theirs-only change
printf 'a\nB\nc\nd\ne\n' > mergeable.txt        # theirs changes line 2
git_quiet rm -q gone.txt                       # theirs deletes the file
printf 'new v1\n'        > newfile.txt          # theirs adds a file
printf 'build v2\n'      > tasks/build          # theirs-only change
printf 'test v2\n'       > tasks/test           # theirs changes a disabled-lane file
printf '#!/bin/sh\necho hi\n' > tasks/newexec   # theirs adds an executable the MOD lacks -> CREATE
chmod +x tasks/newexec
printf '\x00\x01\x02BBBB\n'   > bin.dat          # NUL bytes -> git merge-file hard error -> ERROR
git_quiet add -A
git_quiet commit -m ":sparkles: theirs"

# --- build the derived MOD -------------------------------------------------
mod=$work/mod
mkdir -p "$mod"
cd "$mod" || exit 1
git_quiet init
printf 'v1\n'            > verbatim.txt         # unchanged from base
printf 'a\nb\nc\nd\nE\n' > mergeable.txt        # ours changes line 5 (non-adjacent) -> clean merge
printf 'delete me\n'     > gone.txt             # unchanged from base -> follow deletion
mkdir -p tasks
printf 'build v1\nlocal tweak\n' > tasks/build  # ours changed too -> conflict
printf 'AAAAlocal\n'     > bin.dat              # all three differ -> merge-file runs and hard-errors
git_quiet add -A
git_quiet commit -m ":seedling: mod"
# no .busted, no .github/workflows/ci.yml -> test lane disabled

out=$("$merge" "$scaffold" "$base")
line() { printf '%s\n' "$out" | grep -E "^[A-Z]+ $1$" || true; }

check "verbatim.txt applied clean"  "CLEAN verbatim.txt"      "$(line verbatim.txt)"
check "mergeable.txt merged clean"  "CLEAN mergeable.txt"     "$(line mergeable.txt)"
check "gone.txt deleted"            "DELETE gone.txt"         "$(line gone.txt)"
check "newfile.txt created"         "CREATE newfile.txt"      "$(line newfile.txt)"
check "tasks/build conflict"        "CONFLICT tasks/build"    "$(line tasks/build)"
# No .busted in the MOD -> merge.sh must not emit any line (CREATE/CLEAN least
# of all) for the four test-lane paths, even when the scaffold changed one.
check "ci.yml skipped (no test lane)"       "" "$(line '.github/workflows/ci.yml')"
check ".busted skipped (no test lane)"      "" "$(line '.busted')"
check "tasks/test skipped (no test lane)"   "" "$(line 'tasks/test')"
check "spec/helper.lua skipped (no test lane)" "" "$(line 'spec/helper.lua')"
check "verbatim.txt content"        "v2"                      "$(cat verbatim.txt)"
check "mergeable.txt content"       "$(printf 'a\nB\nc\nd\nE')" "$(cat mergeable.txt)"
check "newfile.txt content"         "new v1"                  "$(cat newfile.txt)"
check "gone.txt removed from tree"  "absent"                  "$([ -e gone.txt ] && echo present || echo absent)"
if grep -q '<<<<<<< ours' tasks/build; then
  echo "ok   - conflict markers present"
else
  echo "FAIL - conflict markers"; fail=1
fi

# --- exec bit on CREATE ----------------------------------------------------
# tasks/newexec is added scaffold-side only and is 100755 there; the CREATE
# branch must chmod +x *before* `git add` so the mode reaches the MOD index.
check "tasks/newexec created"        "CREATE tasks/newexec" "$(line 'tasks/newexec')"
check "tasks/newexec staged 100755"  "100755" "$(git -C "$mod" ls-files -s tasks/newexec | awk '{print $1}')"

# --- symlink SKIP --------------------------------------------------------------
# LINK.md is a tracked symlink in the scaffold; merge.sh must refuse it and
# never write a regular file in its place.
check "LINK.md skipped (symlink)"    "SKIP LINK.md" "$(line 'LINK.md')"
check "LINK.md not created"           "" "$(printf '%s\n' "$out" | grep -E '^CREATE LINK\.md$' || true)"
check "LINK.md not materialised as regular file" "absent-or-symlink" \
  "$(if [ ! -e "$mod/LINK.md" ]; then echo absent-or-symlink; \
     elif [ -L "$mod/LINK.md" ]; then echo absent-or-symlink; \
     else echo "regular:$(cat "$mod/LINK.md")"; fi)"

# --- merge-file hard error -> ERROR -----------------------------------------
# bin.dat differs on all three sides and "theirs" holds NUL bytes, so the
# both-exist branch runs `git merge-file`, which hard-errors. merge.sh must
# report ERROR and leave the path unstaged and intact.
check "bin.dat errored"              "ERROR bin.dat" "$(line 'bin.dat')"
check "bin.dat not staged"            "" "$(git -C "$mod" diff --cached --name-only | grep -x 'bin.dat' || true)"
check "bin.dat not truncated to empty" "AAAAlocal" "$(cat "$mod/bin.dat")"

exit $fail
