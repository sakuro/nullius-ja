# Project

Japanese translation for the Nullius Factorio MOD. This repository holds only
`locale/ja/*.cfg` translations (plus `locale/en/*.cfg` as upstream reference
for translators) — no Lua source.

# Development

## Available tasks

Run `mise tasks ls -l` to list tasks defined in this project. The `-l` (`--local`) flag excludes tasks inherited from mise's global config, which are unrelated to this project.

## Build and Install

- `mise run install` - Install to local Factorio MOD directory. Uses `git archive` internally, so only committed files are included — commit changes before running.

## Temporary files

Use the `tmp/` directory for temporary files. Create it if it doesn't exist. It is gitignored.

## Release

Releases are handled by GitHub Actions workflows. Do not run `mise run release:*` tasks manually.

Changelog is managed by `factorix mod changelog` and follows Factorio's changelog.txt specification.

### What to write in changelog.txt

- Regular releases: limit entries to user-visible changes only.
- Initial release: write "Initial release" only, under the `Features` category.

### Updating the changelog during development

`Version: Unreleased` marks the not-yet-released section. The release workflow renames it to the released version and does not open a new one, so between releases `changelog.txt` starts with the last released version. Add a fresh `Unreleased` section at the top for the first user-visible change of a new cycle; put later entries in that same section.

Do not create a section for the next release version directly — version bumping is handled by the GitHub Actions release workflow.

# Document Map

- README.md: Project overview
- CONTRIBUTING.md: Pull request guidelines

# External References

- [Factorio API](https://lua-api.factorio.com/latest/)
- [Factorio Wiki](https://wiki.factorio.com/)
- Game directories (mod dir, user dir, data dir, etc.): `factorix path --json | jq -r .<field>` (e.g. `.mod_dir`)
