# Backup Paperless with Restic

* Backup to a local HDD
* Backup to Azure Blog storage

## Backup every night a 04:00

Add this to `crontab -e`.

```text
0 4 * * * /home/me/paperless-compose/paperless-backup-restic.sh >/dev/null 2>&1
```

## Env

```shell
###############################################################################
# Paperless restic backup settings
###############################################################################

# General settings
PAPERLESS_BACKUP_LOGFILE="/home/me/paperless-backup-restic.log"
PAPERLESS_BACKUPDIR_TEMP="/tmp/paperless_backup/db"

# Restic settings
PAPERLESS_RESTIC_INCLUDE_FILE="/paperless/backup/include.txt"
PAPERLESS_RESTIC_EXCLUDE_FILE="/paperless/backup/exclude.txt"
PAPERLESS_RESTIC_PASSWORD="changeMe"
PAPERLESS_RESTIC_FORGET_POLICY="--keep-within-daily 56d --keep-within-weekly 6m --keep-within-monthly 1y --keep-within-yearly 5y"
PAPERLESS_RESTIC_REPO_LOCAL="/media/intenso/restic/paperless"
PAPERLESS_RESTIC_REPO_AZURE="azure:restic:/paperless"
# PAPERLESS_RESTIC_DRY_RUN="-vv --dry-run"

# Azure account name and key
PAPERLESS_AZURE_ACCOUNT_NAME="accountname"
PAPERLESS_AZURE_ACCOUNT_KEY="changeMe"
```
