# Backup Paperless with Restic

* Backup to a local HDD
* Backup to Azure Blog storage

## Backup every night at 03:30 (prune Sundays at 04:00)

Add this to `crontab -e`. The jobs log to the systemd journal via `logger` (collected
by the observability stack, which alerts on failed/missing runs) and keep the local
log file via `tee`; `LOGFILE=/dev/stdout` redirects the scripts' internal `>>` appends
into the pipe. Note the backup script reads `PAPERLESS_LOGFILE`, the prune script
`PAPERLESS_BACKUP_LOGFILE`:

```text
30 3 * * * PAPERLESS_LOGFILE=/dev/stdout /home/bruno/paperless-ngx-compose/backup/paperless_backup_restic.sh 2>&1 | tee -a /home/bruno/paperless-backup-restic.log | logger -t paperless-backup
0 4 * * 0 PAPERLESS_BACKUP_LOGFILE=/dev/stdout /home/bruno/paperless-ngx-compose/backup/paperless_backup_restic_prune.sh 2>&1 | tee -a /home/bruno/paperless-backup-restic.log | logger -t paperless-prune
```

The `logger -t` tags (`paperless-backup`, `paperless-prune`) are matched by the
`backup_alerts` Loki rules in the home-monitoring-stack repo — keep them in sync.

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
# PAPERLESS_RESTIC_ARGS="-vv --dry-run"

# Additional args for restic prune command
# PAPERLESS_RESTIC_PRUNE_ARGS="-v"

# Restic Azure account credentials
PAPERLESS_AZURE_ACCOUNT_NAME="accountname"
PAPERLESS_AZURE_ACCOUNT_KEY="changeMe"
```
