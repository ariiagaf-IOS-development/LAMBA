# LAMBA

## Development Setup

Project dependencies are declared in:

- `go.mod` / `go.sum` for application dependencies.
- `tools/tools.go` for Go-based developer tools such as `swag`.
- `scripts/` for repeatable local setup, development, and test commands.

Required local tools:

- Go 1.22+
- PowerShell
- `make` is optional

Current helper scripts are Windows/PowerShell-first. The Go application itself is cross-platform, but Linux/macOS helper scripts should be added when the team actually needs those environments.

First-time setup on Windows:

```powershell
.\scripts\setup.ps1
```

If PowerShell blocks script execution:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1
```

The setup script downloads Go module dependencies and installs the pinned `swag` CLI version.

If `make` is available, the same setup can be started with:

```powershell
make setup
```

## Daily Development

Start the backend with Swagger regeneration:

```powershell
.\scripts\dev.ps1
```

Or, if `make` is available:

```powershell
make dev
```

`make` targets call the same PowerShell scripts, so they are also intended for the current Windows development setup.

Run checks:

```powershell
.\scripts\test.ps1
```

Or:

```powershell
make test
```

## Backend Quick Start

The backend is initialized as a Go + Gin API.

```powershell
.\scripts\dev.ps1
```

Default API address:

```text
http://localhost:8080
```

Health check:

```bash
curl http://localhost:8080/health
```

## Swagger

Swagger UI is enabled at:

```text
http://localhost:8080/swagger/index.html
```

Raw OpenAPI JSON is available at:

```text
http://localhost:8080/swagger/doc.json
```

Run the API and regenerate Swagger docs:

```powershell
.\scripts\dev.ps1
```

Then open `http://localhost:8080/swagger/index.html` in your browser.

After changing Swagger comments in Go code, regenerate docs:

```powershell
.\scripts\dev.ps1
```

Or, if `make` is available:

```powershell
make swagger
make dev
```

`make dev` runs `scripts/dev.ps1`, which regenerates Swagger docs and starts the API.

## Git Workflow

### Purpose

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
