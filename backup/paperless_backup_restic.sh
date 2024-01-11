#!/usr/bin/env bash

# Crontab entry ###############################################################
# 0 4 * * * /path/to/paperless-backup-restic.sh >/dev/null 2>&1

# Note: Make sure export folder exists and restic repos are initialized!

# config ######################################################################
LOGFILE="${PAPERLESS_LOGFILE:-/media/paperless/export/backup.log}"

# Restic
INCLUDE_FILE="${PAPERLESS_RESTIC_INCLUDE_FILE:-/paperless/backup/include.txt}"
EXCLUDE_FILE="${PAPERLESS_RESTIC_EXCLUDE_FILE:-/paperless/backup/exclude.txt}"
export RESTIC_PASSWORD="${PAPERLESS_RESTIC_PASSWORD:-changeMe}"
FORGET_POLICY="${PAPERLESS_RESTIC_FORGET_POLICY:---keep-within-daily 7d --keep-within-weekly 6m}"
RESTIC_REPOSITORY_LOCAL="${PAPERLESS_RESTIC_REPO_LOCAL:-/media/myhdd/restic/paperless}"
RESTIC_REPOSITORY_AZURE="${PAPERLESS_RESTIC_REPO_AZURE:-azure:restic:/paperless}"
DRY_RUN="${PAPERLESS_RESTIC_DRY_RUN:-}"

# Azure Storage Account name and key
export AZURE_ACCOUNT_NAME="${PAPERLESS_AZURE_ACCOUNT_NAME:-accountname}"
export AZURE_ACCOUNT_KEY="${PAPERLESS_AZURE_ACCOUNT_KEY:-changeMe}"

# script ######################################################################
ERR=0
printf "\n\n################################################################################\n" >> ${LOGFILE}
printf "  Paperless backup  `date --utc +%FT%TZ`\n" >> ${LOGFILE} 2>&1
printf "################################################################################\n\n" >> ${LOGFILE}

# Create paperless export
docker exec -i paperless-webserver-1 document_exporter -sm ../export/backup >> ${LOGFILE} 2>&1

errtmp=$?
ERR=$(($ERR + $errtmp))
echo "create paperless export" $errtmp >> ${LOGFILE}

# Create testic snapshot - local ----------------------------------------------
export RESTIC_REPOSITORY="${PAPERLESS_RESTIC_REPO_LOCAL}"
echo "$DRY_RUN" | xargs \
restic backup --no-scan \
  --files-from "${INCLUDE_FILE}" \
  --iexclude-file "${EXCLUDE_FILE}" >> ${LOGFILE} 2>&1

errtmp=$?
ERR=$(($ERR + $errtmp))
echo "create restic snapshot - local" $errtmp >> ${LOGFILE} 2>&1

# Create restic snapshot - Azure ----------------------------------------------
export RESTIC_REPOSITORY="${PAPERLESS_RESTIC_REPO_AZURE}"
echo "$DRY_RUN" | xargs \
restic backup --no-scan \
  --files-from "${INCLUDE_FILE}" \
  --iexclude-file "${EXCLUDE_FILE}" >> ${LOGFILE} 2>&1

errtmp=$?
ERR=$(($ERR + $errtmp))
echo "create restic snapshot - Azure" $errtmp >> ${LOGFILE}

# Cleanup paperless export ####################################################
rm -rf /media/paperless/export/backup/*
errtmp=$?
ERR=$(($ERR + $errtmp))
echo "cleanup paperless export" $errtmp >> ${LOGFILE}

# Cleanup restic repos --------------------------------------------------------
# local
export RESTIC_REPOSITORY="${PAPERLESS_RESTIC_REPO_LOCAL}"
echo "$FORGET_POLICY" "$DRY_RUN" | xargs \
restic forget >> ${LOGFILE} 2>&1

errtmp=$?
ERR=$(($ERR + $errtmp))
echo "cleanup restic snapshots - local " $errtmp >> ${LOGFILE}

# Azure
export RESTIC_REPOSITORY="${PAPERLESS_RESTIC_REPO_AZURE}"
echo "$FORGET_POLICY" "$DRY_RUN" | xargs \
restic forget >> ${LOGFILE} 2>&1

errtmp=$?
ERR=$(($ERR + $errtmp))
echo "cleanup restic snapshots - Azure " $errtmp >> ${LOGFILE}

echo "Total ERR" $ERR >> ${LOGFILE}
