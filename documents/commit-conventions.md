# Commit message conventions

This document defines the conventions for commit messages in this fork.  
The goal is to keep history readable, searchable and consistent.

## General rules

- Write commit messages **in English**.
- Use the **imperative form** in the subject line (e.g. `Add`, `Fix`, `Update`, not `Added`, `Fixed`).
- Keep the subject line short and descriptive (ideally **≤ 72 characters**).
- If needed, add a blank line after the subject and then a more detailed description.
- Reference issues or tickets when relevant (e.g. `Refs: JIRA-123`, `Fixes #42`).

## Recommended commit types

Use a short type at the beginning of the subject to indicate the intent of the change:

- `feat:` – new feature.
- `fix:` – bug fix.
- `chore:` – maintenance tasks, config changes, tooling.
- `docs:` – documentation only.
- `refactor:` – code changes that do not change behavior.
- `test:` – adding or updating tests.
- `build:` – changes to build system, CI/CD, Docker, workflows.

### Examples

- `feat: add user invite flow to admin panel`
- `fix: prevent crash when opening empty project`
- `docs: add upstream sync documentation`
- `build: add GitHub Actions workflow for upstream sync`
- `chore: ignore local env file in .gitignore`

## Body (optional but recommended)

Use the body to explain **why** the change was made and any important context:

- What problem does this commit solve?
- Are there breaking changes?
- Are there manual steps required (migrations, config changes)?

Example:

```text
build: add GitHub Actions workflow for upstream sync

Adds a scheduled workflow that keeps this fork in sync with penpot/penpot main.
The workflow also merges main into develop when new upstream commits are found.
```

## Merge commits

When creating merge commits manually, use a clear subject:

- `Merge upstream/main into main`
- `Merge main into develop`
- `Merge develop into production`

For automatic merges performed by GitHub Actions, keep the default messages or use similar wording, always in English.

## Small vs. large commits

- Prefer **small, focused commits** that do one thing well.
- Avoid mixing unrelated changes (for example, “build + refactor + docs” in the same commit) unless there is a strong reason.

