---
name: factorio-portal-description
description: Overwrites the Factorio MOD portal description with the repository's README.md via factorix. Use when the user wants to update, sync, push, or publish the MOD portal description (or "portal page") from README.md, even if they do not name the command.
allowed-tools: [Bash, Read]
---

# Factorio MOD Portal Description Sync Skill

Replaces the description on the Factorio MOD portal with the contents of `README.md` in the current MOD repository.

## Instructions

**IMPORTANT: When using this skill, announce to the user**: "Using factorio-portal-description skill to update the MOD portal description."

### 1. Resolve the MOD name

Run from the repository root. The portal name is the `name` field of `info.json`, not the directory name.

```bash
jq -r .name info.json
```

Stop and report if `info.json` or `README.md` is missing.

### 2. Check what will be published

The command publishes the working-tree `README.md`, so uncommitted edits or a non-default branch would go live. Check:

```bash
git status --short README.md
git branch --show-current
```

If `README.md` is modified or the branch is not the default branch, tell the user and ask whether to continue. Overwriting the portal description is outward-facing and not easily reverted.

### 3. Update the description

```bash
fnox exec -- factorix mod edit <mod-name> --description "$(cat README.md)"
```

`fnox exec` supplies the portal API credentials (`FACTORIO_API_KEY`); do not read or print them.

The first run can be slow because fnox has to fetch the secret, and it may prompt for authentication to the password storage. Run the command with a long timeout (e.g. 600000 ms) and tell the user beforehand that an authentication prompt may appear and needs their action. Do not treat a long silence as a hang or retry the command.

### 4. Report

Report the MOD name and whether the command succeeded. On failure, show the error output as is.
