# Contributing

## Development setup

This project manages its toolchain with [mise](https://mise.jdx.dev/). After cloning:

1. `mise trust` — `mise.toml` defines `[env]` and `[hooks]`, which mise applies only for trusted configs.
2. `mise install` — installs the pinned tools. Its `postinstall` hook then runs `hk install` to register this repository's Git hooks, and installs `luacheck` for static analysis.

Review `hk.pkl` and the `git-hooks` package it imports before running the above: `hk install` configures hooks that execute on every commit and push. They enforce, among other things, that commit subjects start with a GitHub `:emoji:` code.

Then `mise run format` formats Lua code, `mise run lint` runs `luacheck`, and `mise tasks ls -l` lists this project's tasks (`-l` drops tasks inherited from mise's global config).

### Notes

- Re-run `mise install` after pulling changes to `mise.toml`; Renovate bumps tool versions regularly.
- `mise run build` needs `unzip` (preinstalled on macOS and most Linux distributions): it reads the commit ID stored in the existing archive to decide whether to rebuild it.

## Pull requests

When opening a pull request:

- Do not change the version in `info.json`. Version bumping is handled by the release workflow.
- Document any user-visible change in `changelog.txt` (see below).

## Comment conventions

Public functions — `function Module.name(...)` and `function Module:name(...)` —
carry a doc comment in three layers:

```lua
--- Rounds value up to the next multiple of size.
---
--- Pressing "+1 Stack" always adds at least one full stack, so the result is
--- strictly greater than value even when value is already an exact multiple.
---@param value number
---@param size number
---@return number
function Module.round_up(value, size)
```

- The **summary** is one line, required, and starts with a verb in the present
  tense (`Decides ...`, `True when ...`). It is not a restatement of the
  function's name.
- The **rationale paragraph** is optional and says *why*, not *what*: behavior
  confirmed over RCON, a Factorio quirk being worked around, why the caller
  passes a value already extracted from the runtime. What the function does is
  the summary's and the tags' job, so it is not repeated here. This is why one
  function has a three-line comment and another fifteen: the difference is how
  much rationale there is to record, not how carefully it was documented.
- **`---@param`** appears once per declared parameter, in declaration order.
  Obvious ones carry only a type; ones with a contract carry a note
  (`---@param filters LuaLogisticPoint.filters  plain array, already extracted by the caller`).
  `self` is implicit in a `:` declaration and is not documented. Varargs are
  `---@param ... <type>`.
- **`---@return`** appears once per returned value, in order, and includes
  `|nil` when nil is a possible result (`---@return LuaTechnology|nil`). A
  function that returns nothing gets no tag.
- Type names use the Factorio API's own spelling (`LuaPlayer`, `LuaLogisticPoint`,
  `uint`) or plain Lua types (`string`, `number`, `boolean`, `table`). Nothing
  reads these as types — no language server runs here — so they are documentation
  for human readers, and a `table` whose shape matters is better described by the
  API name it mirrors plus a note.
- Comments **inside** a function body stay there. A comment explaining why one
  line is the way it is belongs next to that line; only the description of the
  function itself belongs above it.
- Comment lines wrap at about 88 columns, like the code around them; `luacheck`'s
  hard limit is 120. A tag's note that does not fit continues on the next line,
  indented under the tag:

  ```lua
  ---@param requester_point LuaLogisticPoint|nil  only `logistic_network` is read;
  ---  extracted by the caller, e.g. TemporaryRequestAction.requester_point_for
  ```

- "Public" means reachable from outside the module, whichever syntax gets it there:
  a `function Module.name(...)` definition, or a `local function` the module hands
  out through its final `return` (bare or in a table) or an assignment onto the
  module table. An exported local is documented at its own definition, which is
  where a reader looks. Locals that stay inside the module are the author's
  judgement call: document the ones that are not obvious from their name and a few
  lines of body. If a local is exported only so a spec can reach it, that export is
  still public — either document it or test it through the public entry point.

`mise run doc-check` enforces the mechanical half of this: a `---` block with a
summary line, one `---@param` per declared parameter in the right order, and a
`---@return` on any function that returns a value. It does not check types or
prose. It reads every Lua file the mod loads — `lib/`, `prototypes/`, and the
stage entry points at the root. `spec/` is test code and `tools/` holds
standalone dev scripts, so neither is in scope. CI runs it in the `lint` job.

Should a batch of undocumented code arrive at once — a large import, say —
`mise run doc-check -- --write-baseline > .doc-check-baseline` captures it and
`--baseline .doc-check-baseline` in `tasks/doc-check` suppresses it while it is
worked through. Such a list can only shrink: `doc-check` fails on an entry whose
function is now documented or gone, and on a baseline with no entries left, which is
how the last one gets deleted.

`tools/doc_check_test.sh` is the checker's own fixture test. CI does not run it,
since every MOD's copy matches the scaffold's; after changing `tools/doc_check.lua`,
run `bash tools/doc_check_test.sh` locally. A doc checker that silently passes
everything would make the baseline a lie, so such a change belongs with a case in
that test.

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

- The PR is opened with `GITHUB_TOKEN`, which does not trigger `pull_request`
  workflows, so the drift workflow dispatches `lint.yml` (and `spec.yml`)
  on the branch itself. To re-run them, use the Actions page or
  `gh workflow run lint.yml --ref chore/scaffold-drift`.
- Require the `format-check` and `lint` checks (and `spec`, if this repo has the
  test lane) to pass.
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

Only with a `CLAUDE_CODE_OAUTH_TOKEN` repo secret set; blank means the workflow's
gate step no-ops. A fork does not inherit the secret, so the workflow does
nothing on a fork. GitHub disables a scheduled workflow in a public repository
after 60 days without repository activity, so drift detection stops silently on
a MOD that has gone quiet.

The first scheduled run can fail the action's `checkHumanActor` check because
`github.actor` on a `schedule` event is not a `User`. If that happens, set the
`claude-code-action` `allowed_bots` input in `scaffold-drift.yml`.

**Authentication**

`CLAUDE_CODE_OAUTH_TOKEN` authenticates against a Claude subscription, so a run
draws down subscription usage instead of Claude Console API credits. Generate it
once with `claude setup-token` and set the same token in every derived MOD:

```sh
gh secret set CLAUDE_CODE_OAUTH_TOKEN
```

`bin/initialize` prompts for it when a MOD is created from the scaffold. That
secret is the only out-of-band step — everything else rides along with the
scaffold copy.

The token does not auto-refresh (`anthropics/claude-code-action#727`). When it
expires, every derived MOD fails in the same week with an identical signature:
the `Resolve drift` step ends after a few hundred milliseconds with
`is_error: true`, `num_turns: 1`, and `total_cost_usd: 0`, and no error text,
because the action hides Claude's output by default. That signature means the
credential is unusable, not that the merge failed. Recover by re-running
`claude setup-token` and re-setting the secret in every MOD.

To read the real error, re-run one MOD by hand with the `debug` input, which
turns on the action's `show_full_output`:

```sh
gh workflow run scaffold-drift.yml -f debug=true
```

Leave it off otherwise. Full output includes tool results, which may carry
secrets, and a public repository's Actions logs are public too.

**Test lane**

A repo with no `.busted` file has dropped the test lane. The sync never re-adds
the test files (`.github/workflows/spec.yml`, `.busted`, `tasks/test`,
`spec/helper.lua`) or the busted fragments in `mise.toml` /
`.github/renovate.json`. Lua stays installed for luacheck.

**If a sync looks wrong**

Close the PR. The next weekly run force-pushes `chore/scaffold-drift` again and
opens a fresh PR from the same baseline (the merge is recomputed each run). To
move the baseline, edit `.scaffold-sync.json`. The canonical description of this
mechanism is this section plus `.github/workflows/scaffold-drift.yml`,
`.scaffold-sync.paths`, and `.claude/skills/resolve-scaffold-drift/`.
