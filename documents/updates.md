# Updates Guide - Synchronization with Upstream

This guide describes the process of synchronizing with the official Penpot repository to receive fixes and new features.

## Overview

The update process involves:
1. Fetching updates from the official repository (upstream)
2. Merging into the `main` branch (mirror of upstream)
3. Resolving conflicts (if any)
4. Testing in staging environment
5. Merging into the `production` branch
6. Deploy to production

## Branch Strategy

```
upstream/main (official)
    │
    │ fetch + merge
    ▼
main (our mirror)
    │
    │ merge
    ▼
develop (customizations + upstream)
    │
    │ merge (after tests)
    ▼
production (deploy)
```

### Branch Description

- **`main`**: Exact mirror of `upstream/main`. Never commit directly here.
- **`develop`**: Development branch with our customizations applied on top of upstream.
- **`production`**: Stable tested version ready for deploy.

## Update Process

### 1. Automatic Synchronization

Use the provided script:

```bash
./scripts/update-from-upstream.sh
```

This script:
- Fetches from upstream repository
- Merges into `main` branch
- Detects and reports conflicts
- Shows merge statistics

### 2. Manual Process

If you prefer to do it manually:

```bash
# 1. Ensure you're on main branch
git checkout main

# 2. Fetch updates
git fetch upstream

# 3. See what changed
git log HEAD..upstream/main --oneline

# 4. Merge
git merge upstream/main --no-ff -m "Merge from upstream $(date '+%Y-%m-%d')"

# 5. If there are conflicts, resolve (see section below)
```

### 3. Conflict Resolution

#### Identify Conflicts

```bash
# View conflicted files
git status

# View conflict details
git diff
```

#### Resolution Strategies

**Scenario 1: File you didn't customize**
```bash
# Accept upstream version
git checkout --theirs path/to/file.clj
git add path/to/file.clj
```

**Scenario 2: File you customized**
```bash
# Keep your version (careful: may lose upstream fixes)
git checkout --ours path/to/file.clj
git add path/to/file.clj
```

**Scenario 3: Both modified (manual resolution)**
```bash
# Open file and resolve manually
# Look for markers:
# <<<<<<< HEAD (your version)
# =======
# >>>>>>> upstream/main (upstream version)
```

#### Complete the Merge

After resolving all conflicts:

```bash
git add .
git commit -m "Resolve conflicts from upstream merge"
```

### 4. Test Updates

#### In Development Environment

```bash
# Merge into develop
git checkout develop
git merge main

# Rebuild images
./scripts/build-images.sh

# Test locally
./scripts/setup.sh --skip-build
```

#### Test Checklist

- [ ] Application starts without errors
- [ ] Login works
- [ ] Project creation works
- [ ] Design editing works
- [ ] Export works
- [ ] Customizations still work
- [ ] No errors in logs

### 5. Deploy to Production

After successful tests:

```bash
# Merge into production
git checkout production
git merge develop

# Release tag (optional)
git tag -a v$(date +%Y%m%d) -m "Release $(date +%Y-%m-%d)"

# Build images
./scripts/build-images.sh

# Deploy (adjust according to your process)
docker compose -f docker-compose.production.yml pull
docker compose -f docker-compose.production.yml up -d
```

## Update Frequency

### Recommendations

- **Security Fixes**: Immediately after release
- **Minor Releases**: Bi-weekly
- **Major Releases**: Monthly or as needed

### Monitoring

Set up alerts for:
- [GitHub Releases](https://github.com/penpot/penpot/releases)
- [Penpot Changelog](https://github.com/penpot/penpot/blob/main/CHANGES.md)
- [Penpot Community](https://community.penpot.app/) for announcements

## Database Migrations

### Check Required Migrations

Penpot manages migrations automatically, but it's important to:

1. **Backup Before Updating**:
   ```bash
   docker compose -f docker-compose.production.yml exec penpot-postgres \
     pg_dump -U penpot penpot > backup-before-update-$(date +%Y%m%d).sql
   ```

2. **Check Changelog**: Consult `CHANGES.md` for schema changes

3. **Test Migrations in Staging**: Always test migrations before production

### Migration Process

```bash
# 1. Stop services
docker compose -f docker-compose.production.yml stop penpot-backend

# 2. Update code
git checkout production
git pull

# 3. Rebuild images
./scripts/build-images.sh

# 4. Start backend (migrations run automatically)
docker compose -f docker-compose.production.yml up -d penpot-backend

# 5. Check logs
docker compose -f docker-compose.production.yml logs -f penpot-backend
```

## Rollback

If something goes wrong after an update:

### Code Rollback

```bash
# Go back to previous commit
git checkout production
git reset --hard HEAD~1

# Rebuild images
./scripts/build-images.sh

# Restart services
docker compose -f docker-compose.production.yml up -d
```

### Database Rollback

```bash
# Restore backup
cat backup-before-update-20240101.sql | \
  docker compose -f docker-compose.production.yml exec -T penpot-postgres \
  psql -U penpot penpot
```

## Update Checklist

### Before Updating

- [ ] Database backup
- [ ] Assets backup (Docker volumes)
- [ ] Check Penpot changelog
- [ ] Check for breaking changes
- [ ] Notify users (if necessary)
- [ ] Schedule maintenance window

### During Update

- [ ] Sync with upstream
- [ ] Resolve conflicts (if any)
- [ ] Test in staging
- [ ] Validate customizations
- [ ] Check migrations

### After Update

- [ ] Check logs of all services
- [ ] Test main functionalities
- [ ] Monitor for 24-48 hours
- [ ] Document issues found
- [ ] Update documentation if necessary

## Troubleshooting

### Merge Fails with Complex Conflicts

```bash
# Abort merge and try different strategy
git merge --abort

# Interactive merge
git merge upstream/main --no-commit
# Resolve conflicts manually
git commit
```

### Update Breaks Customizations

1. Identify which customization broke
2. Check Penpot changelog
3. Adapt customization to new API
4. Test extensively
5. Document necessary changes

### Database Migration Fails

```bash
# View detailed logs
docker compose -f docker-compose.production.yml logs penpot-backend | grep -i migration

# Restore backup
# (see Rollback section above)

# Report issue on Penpot GitHub
```

## Automation (Optional)

### Automatic Update Script

Create a script `scripts/auto-update.sh`:

```bash
#!/usr/bin/env bash
set -e

# Backup
./scripts/backup.sh

# Update
./scripts/update-from-upstream.sh

# Test
./scripts/test.sh

# If tests pass, deploy
if [ $? -eq 0 ]; then
    git checkout production
    git merge develop
    ./scripts/deploy.sh
fi
```

### CI/CD (GitHub Actions)

Example workflow `.github/workflows/update-upstream.yml`:

```yaml
name: Update from Upstream

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
  workflow_dispatch:

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Update from upstream
        run: ./scripts/update-from-upstream.sh
      - name: Create PR
        # Automatically create PR if there are changes
```

## Additional Resources

- [Penpot Git Workflow](https://help.penpot.app/contributing-guide/)
- [Changelog](https://github.com/penpot/penpot/blob/main/CHANGES.md)
- [Releases](https://github.com/penpot/penpot/releases)
