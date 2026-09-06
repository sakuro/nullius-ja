# Contributing

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
