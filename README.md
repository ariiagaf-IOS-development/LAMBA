# Git Workflow

## Purpose

This document defines the current development flow for the project.

## Before You Start

- Check the repository status:

```bash
git status --short
```

- Do not leave unfinished work or temporary test/debug files in the working tree.
- Do not commit unrelated files or temporary artifacts (including generated screenshots).

## Workflow

Before making changes:

```bash
git switch main
git pull --rebase
git switch -c feature/task-name
```

Branch prefixes:

- `feature/` — functionality changes.
- `fix/` — bug fixes.
- `refactor/` — code improvements without behavior changes.
- `docs/` — documentation changes.
- `test/` — tests additions/updates.
- `chore/` — maintenance and housecleaning.

Use kebab-case for branch names:

```text
feature/order-editor-autosave
fix/notification-reconnect
docs/git-workflow
```

### Working Steps

1. Create your branch from updated `main`.
2. Make the required code changes.
3. Review your diffs before committing:

```bash
git diff
git diff --staged
```

## Commit Message Convention

Commit message pattern:

```text
type(scope): short description
```

Examples:

```text
feat(orders): add autosave status indicator
fix(notifications): keep REST backfill after ws failure
docs: add git workflow
test(auth): cover session expired redirect
```

Allowed commit types:

- `feat`
- `fix`
- `refactor`
- `docs`
- `test`
- `chore`
- `build`

Before committing:

```bash
git status --short
git diff --staged
```

Commit:

```bash
git add <files>
git commit -m "docs: add git workflow"
```

## Handling Conflicts

If your branch is behind:

```bash
git fetch origin
git rebase origin/main
```

After resolving conflicts:

```bash
git status --short
git add <resolved_files>
git rebase --continue
```

If a force push is required after rebase:

```bash
git push --force-with-lease
```

## Pull Request

Before opening PR:

- PR should contain meaningful changes only and not be empty.
- Request review from teammates.

Include at least this PR body template:

```md
## What is done?

Describe the task and scope.

## How was it done?

Short description of implementation.

## Validation

What should be checked?

## Additional checks

- Drive-by fixes: <if any>
```

## Merge

Before merge:

- The branch changes must match the task scope.
- CI and code review checks should pass.
- All review comments must be addressed.
- Final verification should be clean.

After merge, clean local and remote branches:

```bash
git switch main
git pull --rebase
git branch -d feature/task-name
git push origin --delete feature/task-name
```

