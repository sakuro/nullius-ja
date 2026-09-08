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
