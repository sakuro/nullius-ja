---
name: resolve-scaffold-drift
description: Use when syncing this repository with factorio-mod-scaffold — resolving "scaffold drift", running a scaffold-drift check, or producing/updating a chore/scaffold-drift PR. Three-way merges the tracked shared-infrastructure files against the current scaffold.
---

# Resolve Scaffold Drift

This repository was generated from `factorio-mod-scaffold`. Shared infrastructure
(workflows, `mise.toml`, Renovate config, git-hook config, tasks, test
scaffolding, `AGENTS.md` / `CONTRIBUTING.md` prose) is meant to track the
scaffold. This skill brings it back in sync as a three-way merge and opens or
updates one PR.

## Inputs

- `.scaffold-sync.json` at the repo root — `{ "repo", "commit", "synced_at" }`.
  `commit` is the scaffold commit this repo was last synced to (the merge base).
- The scaffold's own `.scaffold-sync.paths` — the authoritative list of tracked
  paths. Never trust the local copy for the path list; read it from the fresh
  clone.

## Procedure

Create a TODO per numbered step.

1. **Preconditions.** Run from the repo root (`git rev-parse --show-toplevel`).
   Confirm `gh auth status` succeeds. Confirm the working tree is clean.

2. **Fetch the scaffold.**
   `git clone --filter=blob:none https://github.com/sakuro/factorio-mod-scaffold <clone>`
   (public, no auth). Read `<clone>/.scaffold-sync.paths`.

3. **Baseline.** Read `.scaffold-sync.json` for `.commit` (the merge base).
   - If it is missing, this is **bootstrap mode**: get the first commit's
     authored date with `git log --reverse --format=%aI | head -1`, then find the
     scaffold commit that was current then, using the clone from step 2:
     `git -C <clone> rev-list -1 --before="<date>" origin/HEAD`.
     If that prints nothing — the MOD's history predates the scaffold's — fall
     back to the scaffold's root commit:
     `git -C <clone> rev-list --max-parents=0 origin/HEAD | tail -1`.
     Show the resulting SHA and ask the user to confirm before continuing.
     (In an unattended run with no `.scaffold-sync.json`, stop and report — do
     not guess silently.)

4. **Mechanical merge.** Run
   `bash <clone>/.claude/skills/resolve-scaffold-drift/merge.sh <clone> <baseline-sha>`
   from the repo root — invoke it through `bash` explicitly. `merge.sh` needs
   bash ≥ 4 (`declare -A`); on macOS use a non-system bash (Homebrew etc.),
   because bash 3.2 makes it exit 2 without merging anything. It applies clean
   results and prints one line per path:
   `CLEAN` / `CREATE` / `DELETE` / `CONFLICT` / `SKIP`. Keep the output.
   An `ERROR <path>` line means `merge.sh` could not process that path — stop
   and report it, do not commit.

5. **Resolve conflicts.** For every `CONFLICT <path>`, open the file and resolve
   the `<<<<<<< ours` / `||||||| base` / `>>>>>>> theirs` markers by hand:
   - Keep MOD-specific content: `mise.toml` `[env] MOD_LICENSE/MOD_CATEGORY/MOD_TAGS`,
     `AGENTS.md` / `CONTRIBUTING.md` sections the MOD added, real `spec/*_spec.lua`.
   - Version-line conflicts (a tool version in `mise.toml`, a pinned action SHA):
     take the **newer** version. Never downgrade.
   - Otherwise take the scaffold's intent.
   `git add` each resolved file.

6. **Test-lane fragments.** If this repo has no `.busted` file, the test lane is
   disabled. Remove these fragments from the merged `mise.toml` /
   `.github/renovate.json` — drop any a clean merge pulled in from the scaffold,
   and resolve conflicts in these regions toward removal:
   - `mise.toml` `[tools]` — the `lua` entry.
   - `mise.toml` `[hooks].postinstall` — the `luarocks install --local busted`
     array element and its `luarocks --version` guard, plus the busted / luarocks
     comment lines.
   - `.github/renovate.json` `packageRules` — the rule with
     `matchManagers: ["mise"]`, `matchDepNames: ["lua"]`, `enabled: false`.
   - `.github/renovate.json` `customManagers` — the `lunarmodules/busted` regex
     manager.
   `git add` the results.

7. **Hold back paths this run cannot apply.** Two path classes can't be carried
   by an automated (CI) run:
   - **`.github/workflows/**`** — `git push` by `GITHUB_TOKEN` is rejected
     ("without `workflows` permission" — a `GITHUB_TOKEN` cannot be granted it).
     The merged result is staged but unpushable.
   - **`.claude/**`** — the CI agent's own sandbox denies writes there, so
     `merge.sh` / a manual conflict edit could not produce the merged result in
     the first place. (A local `/resolve-scaffold-drift` run is not sandboxed and
     has none of these limits.)

   For each affected path:
   - Work out the intended change: for a staged workflow file,
     `git --no-pager diff --cached -- <path>`; for a `.claude/**` path the run
     couldn't write, diff this repo's version against the scaffold's,
     `git --no-pager diff --no-index <path> <clone>/<path>` (resolve conflicts
     the same way step 5 would — usually the scaffold's version).
   - Revert / leave it unchanged locally: `git restore --staged --worktree -- <path>`.
   - Set `held_back=1`.

   Workflow drift that is only `uses:` SHA/tag pin bumps needs no action — each
   MOD's Renovate converges those. Structural changes (a new job, `permissions:`,
   a model pin) and any `.claude/**` change need a hand-apply.

8. **Nothing to do?** If `git diff --cached --quiet` (nothing was staged by steps
   4–7, and step 9 has not written `.scaffold-sync.json` yet) **and** `held_back`
   is unset, delete the clone and stop — report "no drift". Do not create a
   branch or PR. If only held-back paths changed (nothing else staged), go on —
   step 9 leaves the baseline alone and step 10 still opens/updates the PR so the
   held-back diffs are visible.

9. **Bump the baseline — only if nothing was held back.** If `held_back` is set,
   leave `.scaffold-sync.json` unchanged, so the held-back drift stays
   detectable on the next run. Otherwise rewrite it: `commit` = the scaffold
   clone's HEAD SHA (`git -C <clone> rev-parse HEAD`), `synced_at` = now
   (`date -u +%Y-%m-%dT%H:%M:%SZ`), `repo` unchanged. `git add .scaffold-sync.json`.

10. **Branch, commit, PR.**
   - **Guard:** `git grep -nE '^(<<<<<<<|>>>>>>>|\|\|\|\|\|\|\|)' -- $(git diff --cached --name-only)`
     must print nothing. If any conflict marker remains, go back to step 5 —
     never commit marker lines. (`=======` is omitted on purpose: a 7-`=` line
     is also a Markdown setext-heading underline.)
   - `git switch -C chore/scaffold-drift`.
   - Commit:
     `git commit -m ":arrows_counterclockwise: Sync scaffold drift (<short-base>..<short-head>)"`
     where `<short-base>` / `<short-head>` are the 7-char baseline and new SHAs.
   - `git push --force origin chore/scaffold-drift`.
   - If an **open** PR for `chore/scaffold-drift` exists (`gh pr view chore/scaffold-drift --json state -q .state` = `OPEN`), update its body with `gh pr edit`. Otherwise `gh pr create` (a previously closed PR does not block this).
     - Title: `:arrows_counterclockwise: Sync scaffold drift`
     - Body: the list of changed paths grouped by `merge.sh` status, the scaffold
       compare link `https://github.com/sakuro/factorio-mod-scaffold/compare/<base>...<head>`,
       and a short note on each conflict you resolved.
     - If `held_back` is set, add a `## Held back` section — one ` ```diff `
       block per held-back path, and: "apply these by hand (a `.github/workflows/**`
       diff that is only `uses:` SHA/tag bumps can instead be left for this MOD's
       Renovate), then bump `.scaffold-sync.json` `commit` to `<head>` and
       `synced_at` to now." State that the baseline was **not** bumped.
   - `gh pr edit chore/scaffold-drift --add-label chore`.
   - Do **not** add the `run-ci` label — that is the reviewer's trigger, and a
     label set with `GITHUB_TOKEN` would not start CI anyway.
   - Do not touch `changelog.txt`; every tracked path is `export-ignore`d dev
     infrastructure, invisible to MOD users.

11. **Clean up.** Remove the clone.

## Notes

- `merge.sh` already skips the four test-lane whole files when `.busted` is
  absent; step 6 is only the fragments inside files that stay.
- If `merge.sh` prints `CONFLICT` for a delete/modify case (scaffold deleted a
  file this repo still changes, or vice versa), decide per file: usually follow
  the scaffold unless the MOD clearly depends on it, and mention it in the PR body.
- Always operate on the checked-out working tree. Never rebuild the MOD from
  `git archive` — this repo's `.gitattributes` marks the scaffold-tracked files
  (`.busted`, `.github/**`, `tasks/**`, `mise.toml`, …) `export-ignore`, so an
  archive drops exactly what this skill syncs.
