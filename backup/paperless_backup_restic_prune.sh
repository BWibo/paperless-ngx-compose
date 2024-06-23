#!/usr/bin/env bash

# Crontab entry ###############################################################
# 0 4 * * * $HOME/myzsh/tools/nextcloud/nextcloud-backup.sh >/dev/null 2>&1

# config ######################################################################
# General settings
LOGFILE="${PAPERLESS_BACKUP_LOGFILE:-/media/paperless/export/backup.log}"

# Restic setings
export RESTIC_PASSWORD="${PAPERLESS_RESTIC_PASSWORD:-changeMe}"
RESTIC_REPOSITORY_LOCAL="${PAPERLESS_RESTIC_REPO_LOCAL:-/media/myhdd/restic/nextcloud}"
RESTIC_REPOSITORY_AZURE="${PAPERLESS_RESTIC_REPO_AZURE:-azure:restic:/nextcloud}"
RESTIC_PRUNE_ARGS="${PAPERLESS_RESTIC_PRUNE_ARGS:-}"

# Azure Storage Account name and key
export AZURE_ACCOUNT_NAME="${PAPERLESS_AZURE_ACCOUNT_NAME:-accountname}"
export AZURE_ACCOUNT_KEY="${PAPERLESS_AZURE_ACCOUNT_KEY:-changeMe}"

# script ######################################################################
ERR=0
printf "\n\n" >> ${LOGFILE}
echo "-- Paperless restic prune" `date --utc +%FT%TZ` "-----------------------------" \
  >> ${LOGFILE}
printf "\n\n" >> ${LOGFILE}

# Cleanup restic repos ########################################################
# local -----------------------------------------------------------------------
export RESTIC_REPOSITORY="${PAPERLESS_RESTIC_REPO_LOCAL}"
echo "$RESTIC_PRUNE_ARGS"  | xargs \
restic prune >> ${LOGFILE} 2>&1

errtmp=$?
ERR=$(($ERR + $errtmp))
echo "prune restic snapshots - local " $errtmp >> ${LOGFILE}

restic check >> ${LOGFILE} 2>&1

errtmp=$?
ERR=$(($ERR + $errtmp))
echo "check restic repo - local " $errtmp >> ${LOGFILE}

# Azure -----------------------------------------------------------------------
export RESTIC_REPOSITORY="${PAPERLESS_RESTIC_REPO_AZURE}"
echo "$RESTIC_PRUNE_ARGS"  | xargs \
restic prune >> ${LOGFILE} 2>&1

errtmp=$?
ERR=$(($ERR + $errtmp))
echo "prune restic snapshots - Azure " $errtmp >> ${LOGFILE}

restic check >> ${LOGFILE} 2>&1

errtmp=$?
ERR=$(($ERR + $errtmp))
echo "check restic repo - Azure " $errtmp >> ${LOGFILE}

printf "\n\n" >> ${LOGFILE}
echo "Total ERR" $ERR >> ${LOGFILE}
echo "-- Paperless restic prune" `date --utc +%FT%TZ` "done!-----------------------------" \
  >> ${LOGFILE}
printf "\n\n" >> ${LOGFILE}
