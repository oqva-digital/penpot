# Upstream synchronization

This document describes how this fork keeps its branches synchronized with the original Penpot repository.

## Branches

- `main`: mirrors the upstream `penpot/penpot` main branch and contains fork-specific automation/configuration.
- `develop`: integration branch where new changes from `main` are merged before going to production.
- `production`: branch used for production deployments, updated from `develop`.

## Automatic upstream sync (GitHub Actions)

The workflow file is located at:

- `.github/workflows/sync-upstream.yml`

It runs on a schedule (cron) and can also be triggered manually from the **Actions** tab.

### What the workflow does

1. Checks out this repository (`main` branch).
2. Adds the upstream remote: `https://github.com/penpot/penpot.git`.
3. Fetches `upstream/main`.
4. Compares commits between local `main` and `upstream/main`.
5. If there are new commits on `upstream/main`:
   - Merges `upstream/main` into `main` (no rebase).
   - Pushes the updated `main` to this fork.
6. Checks out `develop` (creates it if missing).
7. Merges `main` into `develop` and pushes `develop`.

All merge commits created by this workflow use English commit messages and are intended to keep the fork up to date with the upstream project.

## Manual sync / conflict resolution

If the workflow fails due to merge conflicts, synchronization must be done manually:

```bash
git checkout main
git fetch upstream
git merge upstream/main

# Resolve conflicts, then:
git add .
git commit -m "Resolve upstream merge conflicts"
git push origin main
```

Then update `develop` and `production` as needed:

```bash
git checkout develop
git merge main
git push origin develop

git checkout production
git merge develop
git push origin production
```

After conflicts have been resolved and branches are up to date, the GitHub Actions workflow can be re-run normally.

