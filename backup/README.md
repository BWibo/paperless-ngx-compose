# Backup Paperless with Restic

* Backup to a local HDD
* Backup to Azure Blog storage

## Backup every night a 04:00

Add this to `crontab -e`.

```text
0 4 * * * /home/me/paperless-compose/paperless-backup-restic.sh >/dev/null 2>&1
```

## Example environment settings

```shell
###############################################################################
# Paperless restic backup settings
###############################################################################

# General settings ------------------------------------------------------------
# Log file and temp folder path
PAPERLESS_BACKUP_LOGFILE="/home/me/paperless-backup-restic.log"
PAPERLESS_BACKUPDIR_TEMP="/tmp/paperless_backup/db"

# Restic settings -------------------------------------------------------------
# Include and exclude file location
PAPERLESS_RESTIC_INCLUDE_FILE="/paperless/backup/include.txt"
PAPERLESS_RESTIC_EXCLUDE_FILE="/paperless/backup/exclude.txt"

# Restic encryption key
PAPERLESS_RESTIC_PASSWORD="changeMe"
# Restic snapshot cleanup policy
PAPERLESS_RESTIC_FORGET_POLICY="--keep-within-daily 56d --keep-within-weekly 6m --keep-within-monthly 1y --keep-within-yearly 5y"
# Restic local and remote repo location
PAPERLESS_RESTIC_REPO_LOCAL="/media/intenso/restic/paperless"
PAPERLESS_RESTIC_REPO_AZURE="azure:restic:/paperless"

# Additional restic args
# PAPERLESS_RESTIC_DRY_RUN="-vv --dry-run"

# Restic Azure account credentials
PAPERLESS_AZURE_ACCOUNT_NAME="accountname"
PAPERLESS_AZURE_ACCOUNT_KEY="changeMe"
```
