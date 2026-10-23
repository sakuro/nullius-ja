---
name: factorio-changelog
description: Generates changelog entries for Factorio MODs from commits since the last release. Use when the user wants to update changelog.txt, add changelog entries, or document changes for a Factorio MOD.
allowed-tools: [Bash, Read, Grep]
---

# Factorio MOD Changelog Generation Skill

Analyzes commits since the last release and adds user-facing changes to `changelog.txt` using `factorix mod changelog add`.

## Instructions

**IMPORTANT: When using this skill, announce to the user**: "Using factorio-changelog skill to generate changelog entries."

### 1. Get Last Release Tag

```bash
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$LAST_TAG" ]; then
  echo "No previous release tag found. Will analyze all commits."
fi
```

### 2. Get Commits Since Last Release

```bash
# If tag exists
git log --format="%H %s" "$LAST_TAG"..HEAD

# If no tag, get recent commits
git log --format="%H %s" -50
```

### 3. Analyze Each Commit

For each commit, determine if it has user-facing impact:

**Include** (user-facing):
- New features (`:sparkles:`)
- Bug fixes (`:bug:`)
- Performance improvements (`:zap:`)
- Breaking changes (`:boom:`)
- Scripting API changes (`:scroll:`)

**Exclude** (internal):
- Refactoring (`:recycle:`) - unless it changes behavior
- Tests (`:white_check_mark:`)
- CI/CD changes (`:construction_worker:`)
- Documentation (`:memo:`) - unless user-facing docs
- Code style (`:art:`)
- Merge commits
- Version/release prep commits (`:bookmark:`)

### 4. Categorize Changes

Map each commit to a Factorio changelog category:

| Commit type | Category |
|---|---|
| New major features | `Features` |
| Minor additions | `Minor Features` |
| Bug fixes | `Bugfixes` |
| Performance improvements | `Optimizations` |
| Breaking changes / behavior changes | `Changes` |
| Scripting/API changes | `Scripting` |

### 5. Determine Target Version

```bash
BRANCH=$(git branch --show-current)

if [[ "$BRANCH" =~ ^release-v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
  TARGET_VERSION="${BASH_REMATCH[1]}"
else
  TARGET_VERSION="Unreleased"
fi
```

### 6. Check Existing Entries

Before adding entries, check what's already in `changelog.txt` to avoid duplicates:

```bash
factorix mod changelog extract --version "$TARGET_VERSION" 2>/dev/null || echo "(no existing entries)"
```

### 7. Add Entries via factorix

For each user-facing change, run:

```bash
factorix mod changelog add "Entry text" --category="CATEGORY" --version="$TARGET_VERSION"
```

Entry text should:
- Start with an imperative verb (Add, Fix, Change, Remove)
- Be concise (one line)
- Focus on user impact, not implementation details

**Do not include issue references** — Factorio's `changelog.txt` is plain text displayed in-game and does not support markdown links.

## Workflow

1. Get last release tag
2. List commits since that tag
3. For each commit:
   - Read commit message
   - Determine if user-facing
   - Map to Factorio category
4. Determine target version (release branch → X.Y.Z, otherwise → Unreleased)
5. Check existing entries to avoid duplicates
6. For each new entry, run `factorix mod changelog add`

## Guidelines

### Entry Writing
- Use imperative mood: "Add" not "Added" or "Adds"
- Be specific but concise
- One logical change per entry
- No issue references or markdown links

### Avoiding Duplicates
- Extract current entries for target version before adding
- Skip entries that already exist

## Arguments

This skill takes no arguments. It always analyzes commits from the last release tag to HEAD.
