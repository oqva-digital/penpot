# Automated Backup Guide

This guide explains how to set up automated backups for your Penpot self-hosted instance.

## Overview

The backup system automatically backs up:
- **PostgreSQL database**: Full database dump using `pg_dump`
- **Assets volume**: Docker volume containing user-uploaded files and assets

Backups are stored in `/opt/penpot/backup/` (or `$PROJECT_ROOT/backup/`) with timestamps.

## Backup Script

The backup script is located at `scripts/backup.sh`.

### Features

- **Automatic retention check**: Only creates backup if no backup exists in the last 7 days
- **Compressed backups**: Database dumps are gzipped to save space
- **Safe execution**: Checks for running containers before attempting backup
- **Initial backup**: Automatically runs on first setup if no backups exist

### Manual Backup

To run a backup manually:

```bash
cd /opt/penpot
bash scripts/backup.sh
```

To force a backup (ignore 7-day check):

```bash
bash scripts/backup.sh --force
```

### Backup Location

Backups are stored in:
```
/opt/penpot/backup/
├── 20240119-143022/
│   ├── penpot_db.dump.gz
│   └── penpot_assets.tar.gz
├── 20240126-143022/
│   ├── penpot_db.dump.gz
│   └── penpot_assets.tar.gz
└── ...
```

Each backup is stored in a timestamped directory: `YYYYMMDD-HHMMSS/`

## Automatic Weekly Backup (Cron)

To set up automatic weekly backups, configure a cron job:

### 1. Edit crontab

```bash
crontab -e
```

### 2. Add weekly backup job

Add this line to run backup every Sunday at 3:00 AM:

```cron
0 3 * * 0 cd /opt/penpot && bash scripts/backup.sh >> /opt/penpot/backup/cron.log 2>&1
```

Or to run every 7 days from a specific date (e.g., every Monday):

```cron
0 3 * * 1 cd /opt/penpot && bash scripts/backup.sh >> /opt/penpot/backup/cron.log 2>&1
```

### 3. Verify cron job

```bash
crontab -l
```

### 4. Test cron job manually

```bash
# Test the command that cron will run
cd /opt/penpot && bash scripts/backup.sh
```

## Initial Backup on Container Start

The `setup.sh` script automatically checks for backups when starting containers. If no backup exists or the last backup is older than 7 days, it will create an initial backup.

This happens automatically when you run:

```bash
./scripts/setup.sh
```

## Restore from Backup

### Restore Database

```bash
# Extract the backup
cd /opt/penpot/backup/20240119-143022
gunzip penpot_db.dump.gz

# Restore to container
docker compose -f docker-compose.production.yml exec -T penpot-postgres \
  pg_restore -U penpot -d penpot -c < penpot_db.dump
```

Or using `psql` for plain SQL dumps:

```bash
cat penpot_db.sql | docker compose -f docker-compose.production.yml exec -T penpot-postgres \
  psql -U penpot penpot
```

### Restore Assets Volume

```bash
# Stop services that use the volume
docker compose -f docker-compose.production.yml stop penpot-frontend penpot-backend

# Remove old volume (WARNING: This deletes current assets)
docker volume rm penpot_assets

# Restore from backup
docker run --rm \
  -v penpot_assets:/data \
  -v /opt/penpot/backup/20240119-143022:/backup \
  ubuntu:22.04 \
  tar xzf /backup/penpot_assets.tar.gz -C /data

# Restart services
docker compose -f docker-compose.production.yml start
```

## Backup Retention

- **Automatic**: Script checks if backup exists within last 7 days
- **Manual cleanup**: Old backups are not automatically deleted
- **Recommendation**: Keep at least 4 weekly backups (1 month) and consider off-site storage

### Manual Cleanup

To remove backups older than 30 days:

```bash
find /opt/penpot/backup -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \;
```

## Troubleshooting

### Backup Fails: Container Not Found

**Error**: `penpot-postgres container not found`

**Solution**: Ensure containers are running:
```bash
docker compose -f docker-compose.production.yml ps
docker compose -f docker-compose.production.yml up -d
```

### Backup Fails: Permission Denied

**Error**: `Permission denied` when creating backup directory

**Solution**: Ensure script has write permissions:
```bash
chmod +x scripts/backup.sh
mkdir -p /opt/penpot/backup
chmod 755 /opt/penpot/backup
```

### Cron Job Not Running

**Check cron logs**:
```bash
tail -f /opt/penpot/backup/cron.log
```

**Verify cron service**:
```bash
systemctl status cron  # Debian/Ubuntu
systemctl status crond  # CentOS/RHEL
```

**Check cron execution**:
```bash
# Add this to crontab to test
* * * * * echo "Cron is working" >> /tmp/cron-test.log
# Wait 1 minute, then check /tmp/cron-test.log
```

### Backup Size Too Large

If backups are consuming too much disk space:

1. **Check backup sizes**:
   ```bash
   du -sh /opt/penpot/backup/*
   ```

2. **Remove old backups** (see Manual Cleanup above)

3. **Consider off-site storage**: Copy backups to external storage or cloud

## Best Practices

1. **Test restores regularly**: Periodically test restoring from backups to ensure they work
2. **Off-site backups**: Copy backups to external storage or cloud (S3, Google Drive, etc.)
3. **Monitor disk space**: Ensure `/opt/penpot/backup` has sufficient space
4. **Document restore procedures**: Keep this guide accessible for your team
5. **Backup before updates**: Always backup before major updates (see [Updates Guide](UPDATES.md))

## Integration with Update Process

The backup script integrates with the update process:

- **Before updates**: Run `bash scripts/backup.sh --force` to create a backup
- **After updates**: Verify backups are still working correctly

See [Updates Guide](UPDATES.md) for more details on the update workflow.
