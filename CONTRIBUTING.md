# Contributing

## Development setup

This project manages its toolchain with [mise](https://mise.jdx.dev/). After cloning:

1. `mise trust` — `mise.toml` defines `[env]` and `[hooks]`, which mise applies only for trusted configs.
2. `mise install` — installs the pinned tools. Its `postinstall` hook then runs `hk install` to register this repository's Git hooks.

Review `hk.pkl` and the `git-hooks` package it imports before running the above: `hk install` configures hooks that execute on every commit and push. They enforce, among other things, that commit subjects start with a GitHub `:emoji:` code.

`mise tasks ls -l` lists this project's tasks (`-l` drops tasks inherited from mise's global config).

### Notes

- Re-run `mise install` after pulling changes to `mise.toml`; Renovate bumps tool versions regularly.

## Pull requests

When opening a pull request:

- Do not change the version in `info.json`. Version bumping is handled by the release workflow.
- Document any user-visible change in `changelog.txt` (see below).

## Changelog

`changelog.txt` uses Factorio's changelog format. On top of that, this project
marks the section for not-yet-released changes as `Version: Unreleased`. The
release workflow renames that section to the released version and does not open
a new one, so between releases the file starts with the last released version.

The first user-visible change of a new cycle therefore needs a fresh
`Unreleased` section at the top of the file:

```
---------------------------------------------------------------------------------------------------
Version: Unreleased
  Changes:
    - Describe the change here.
```

Add later entries to that same section. Do not create a section for the next
version number — the release workflow does the version bump.

## Scaffold drift

This repository is generated from
[`factorio-mod-scaffold`](https://github.com/sakuro/factorio-mod-scaffold). (In
`factorio-mod-scaffold` itself this workflow is a deliberate no-op — there is no
`.scaffold-sync.json`.) A weekly workflow
(`.github/workflows/scaffold-drift.yml`) three-way merges the
shared-infrastructure files listed in `.scaffold-sync.paths` against the current
scaffold and opens or updates one PR on branch `chore/scaffold-drift` when the
scaffold has moved ahead. `.scaffold-sync.json` records the scaffold commit this
repo was last synced to.

**Reviewing a `chore/scaffold-drift` PR**

- The PR is opened with `GITHUB_TOKEN`, so CI does not start on its own. Add the
  `run-ci` label to start it; CI removes that label as it runs, so after a later
  push from the workflow you re-run CI by adding `run-ci` again. (CI runs
  for real on every `labeled` event — there is no label-name filter, since a
  skipped required check counts as passing — so adding any label also re-runs
  it.)
- Require the test lane (if this repo has one) to pass.
- Check that MOD-specific content survived: `mise.toml` `[env] MOD_*`, any doc
  sections this repo added, real `spec/*_spec.lua`.
- The PR body links the scaffold compare range and notes each conflict the skill
  resolved.
- **Held-back paths.** An automated (CI) drift PR cannot carry changes under
  `.github/workflows/**` (`GITHUB_TOKEN` has no `workflows` permission) or under
  `.claude/**` (the CI agent's sandbox blocks writes there). The PR body's
  "Held back" section has a diff for each; the baseline is *not* bumped and the
  job keeps reporting drift until they are applied. A workflow diff that is only
  `uses:` SHA/tag pin bumps can be left for Renovate; everything else — and every
  `.claude/**` change — is applied by hand (a direct commit or a small PR). Then
  set `.scaffold-sync.json` `commit` to the head SHA in the compare link and
  `synced_at` to the current UTC time. (Running `/resolve-scaffold-drift` locally
  in Claude Code has neither limit and applies everything.)
- `changelog.txt` is intentionally untouched — tracked paths are `export-ignore`d
  development infrastructure.

**When it runs**

Only with an `ANTHROPIC_API_KEY` repo secret set; blank means the workflow's gate
step no-ops. A fork does not inherit the secret, so the workflow does nothing on
a fork and no API cost is incurred.

The first scheduled run can fail the action's `checkHumanActor` check because
`github.actor` on a `schedule` event is not a `User`. If that happens, set the
`claude-code-action` `allowed_bots` input in `scaffold-drift.yml`.

**Test lane**

A repo with no `.busted` file has dropped the test lane. The sync never re-adds
the test files (`ci.yml`, `.busted`, `tasks/test`, `spec/helper.lua`) or the
Lua-testing fragments in `mise.toml` / `.github/renovate.json`.

**If a sync looks wrong**

Close the PR. The next weekly run force-pushes `chore/scaffold-drift` again and
opens a fresh PR from the same baseline (the merge is recomputed each run). To
move the baseline, edit `.scaffold-sync.json`. The canonical description of this
mechanism is this section plus `.github/workflows/scaffold-drift.yml`,
`.scaffold-sync.paths`, and `.claude/skills/resolve-scaffold-drift/`.
