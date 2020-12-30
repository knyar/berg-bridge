#!/bin/bash
# vim: ts=2:sw=2:sts=2:expandtab

set -e -u -o pipefail

COPY='usr/local/bergcloud-bridge usr/bin/oneshot_bergcloud_bridge.sh etc/ntp.conf'
BACKUP='/usr/local/bergcloud-bridge/endpoint.override'

BRIDGE=${1:-}
BASEDIR="$(cd "$(dirname "$0")"; pwd -P)"
TMP_PREFIX="/tmp/$RANDOM"

if [[ -z "${BRIDGE}" ]]; then
  echo "Usage: $0 <bridge-ip>"
  exit 3
fi

for FILE in $COPY; do
  if [[ ! -e "${BASEDIR}/${FILE}" ]]; then
    echo "${BASEDIR}/${FILE} not found"
    exit 3
  fi
done

echo "Remounting root filesystem in read/write"
ssh root@${BRIDGE} "mount -o remount,rw /"

for FILE in $BACKUP; do
  TMPFILE="${TMP_PREFIX}${FILE##*/}"
  echo "Backing up $FILE"
  ssh root@${BRIDGE} "test -e $FILE && cp $FILE $TMPFILE"
done

for FILE in $COPY; do
  echo "Copying $FILE"
  ssh root@${BRIDGE} "rm -rf /${FILE}.new"
  scp -rp "${BASEDIR}/${FILE}" "root@${BRIDGE}:/${FILE}.new"
  echo "Backing up old $FILE"
  ssh root@${BRIDGE} "rm -rf /${FILE}.bak; test -e /${FILE} && mv /${FILE} /${FILE}.bak || true"
  echo "Moving $FILE in place"
  ssh root@${BRIDGE} "mv /${FILE}.new /${FILE}"
done

for FILE in $BACKUP; do
  TMPFILE="${TMP_PREFIX}${FILE##*/}"
  echo "Restoring $FILE"
  ssh root@${BRIDGE} "test -e $TMPFILE && cp $TMPFILE $FILE"
done

echo "All done. Please reboot the bridge."
