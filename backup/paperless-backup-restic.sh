#!/usr/bin/env bash

# Crontab entry ---------------------------------------------------------------
# 0 4 * * * /path/to/paperless-backup-restic.sh >/dev/null 2>&1

# Note: Make sure export folder exists and restic repos are initialized!

# config ----------------------------------------------------------------------
PAPERLESS_BACKUP_PATHS="${PAPERLESS_BACKUP_PATHS:-/media/paperless/export/backup /media/paperless/consume}"
LOGFILE="${PAPERLESS_LOGFILE:-/media/paperless/export/backup.log}"
ERR=0

# Restic
export RESTIC_PASSWORD="${PAPERLESS_RESTIC_PASSWORD:-changeMe}"

# Azure
export AZURE_ACCOUNT_NAME="${PAPERLESS_AZURE_ACCOUNT_NAME:-accountname}"
export AZURE_ACCOUNT_KEY="${PAPERLESS_AZURE_ACCOUNT_KEY:-changeMe}"

# script ----------------------------------------------------------------------
printf "\n\n################################################################################\n" >> ${LOGFILE}
printf "  Paperless backup  `date --utc +%FT%TZ`\n" >> ${LOGFILE} 2>&1
printf "################################################################################\n\n" >> ${LOGFILE}

# Create paperless export
docker exec -i paperless-webserver-1 document_exporter ../export/backup >> ${LOGFILE} 2>&1

errtmp=$?
ERR=$(($ERR + $errtmp))
echo "create paperless export" $errtmp >> ${LOGFILE}

# Create testic snapshot - local
export RESTIC_REPOSITORY="${PAPERLESS_RESTIC_REPO_LOCAL:-/home/bruno/restic/paperless}"
echo "$BACKUPDIR_DB_TEMP $PAPERLESS_BACKUP_PATHS" | \
  xargs \
  restic backup --no-scan >> ${LOGFILE} 2>&1

errtmp=$?
ERR=$(($ERR + $errtmp))
echo "create restic snapshot - local" $errtmp >> ${LOGFILE} 2>&1

# Create restic snapshot - Azure
export RESTIC_REPOSITORY="${PAPERLESS_RESTIC_REPO_AZURE:-azure:restic:/paperless}"
echo "$BACKUPDIR_DB_TEMP $PAPERLESS_BACKUP_PATHS" | \
  xargs \
  restic backup --no-scan >> ${LOGFILE} 2>&1

errtmp=$?
ERR=$(($ERR + $errtmp))
echo "create restic snapshot - Azure" $errtmp >> ${LOGFILE}

# Cleanup paperless export
rm -rf /media/paperless/export/backup/*
errtmp=$?
ERR=$(($ERR + $errtmp))
echo "cleanup paperless export" $errtmp >> ${LOGFILE}

# Cleanup restic repos
# local
export RESTIC_REPOSITORY=/home/bruno/restic/paperless
restic forget --prune --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 5 >> ${LOGFILE} 2>&1

errtmp=$?
ERR=$(($ERR + $errtmp))
echo "cleanup restic snapshots - local " $errtmp >> ${LOGFILE}

# Azure
export RESTIC_REPOSITORY="azure:restic:/paperless"
restic forget --prune --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 2 >> ${LOGFILE} 2>&1

errtmp=$?
ERR=$(($ERR + $errtmp))
echo "cleanup restic snapshots - Azure " $errtmp >> ${LOGFILE}

echo "Total ERR" $ERR >> ${LOGFILE}
