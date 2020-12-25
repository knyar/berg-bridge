#!/bin/sh
#
# Start the Weminuche Bridge App as a daemon
# Copyright BERG 2012

WRAPPER_LOG=/var/log/bridge_wrapper.log
PY_UPDATE_SCRIPT=/usr/local/bergcloud-bridge/updater.py
PYC_UPDATE_SCRIPT=/usr/local/bergcloud-bridge/updater.pyc
PY_DAEMON_SCRIPT=/usr/local/bergcloud-bridge/weminuche_bridge.py
PYC_DAEMON_SCRIPT=/usr/local/bergcloud-bridge/weminuche_bridge.pyc
PY_ENGTEST_SCRIPT=/usr/local/bergcloud-bridge/engtest.py
PYC_ENGTEST_SCRIPT=/usr/local/bergcloud-bridge/engtest.pyc
PY_DAEMON_OPTS="--daemon --watchdog --webdebug"
PIDFILE=/var/run/bergcloud_bridge.pid
RESTART_LIMIT=5
PACKAGE_DIRECTORY=/usr/local/updates
PACKAGE_UPDATE_FILE="$PACKAGE_DIRECTORY/update.ipk"
CACHED_UBOOT_ENV=/tmp/uboot.env
ENDPOINT_OVERRIDE=/usr/local/bergcloud-bridge/endpoint.override

# Rescue
UPDATE_SERVER="bridge-updates.bergcloud.com"
SFTP_KEY="/etc/ssh_host_dsa_key"
SFTP_USER="rescue"
SFTP_RESCUE_PACKAGE="weminuche_bridge_rescue_A.ipk"
# sftp -i SFTP_KEY
#      -o StrictHostKeyChecking=no
#      -o UserKnownHostsFile=/dev/null ${SFTP_USER}@${UPDATE_SERVER}:${SFTP_RESCUE_PACKAGE} $PACKAGE_UPDATE_FILE


# Keep track of restarts
COUNT=$RESTART_LIMIT

# Store our python exit code here
EXIT_CODE=-1

# precache our env
/usr/sbin/fw_printenv > $CACHED_UBOOT_ENV

while [ 1 ]; do
  export LD_PRELOAD="/usr/lib/libstdc++.so"

  if [ -f $ENDPOINT_OVERRIDE ]; then
      echo "Loading override URL"
    . $ENDPOINT_OVERRIDE
  fi
  echo "Endpoint is $CUSTOM_ENDPOINT"
  if [ -f $PY_DAEMON_SCRIPT ]; then
    echo "Running BERG Cloud daemon"
    /usr/bin/python $PY_DAEMON_SCRIPT $PY_DAEMON_OPTS
    EXIT_CODE=$?
  elif [ -f $PYC_DAEMON_SCRIPT ]; then
    echo "Running compiled BERG Cloud daemon"
    /usr/bin/python $PYC_DAEMON_SCRIPT $PY_DAEMON_OPTS
    EXIT_CODE=$?
  else
    echo "No such script $PY_DAEMON_SCRIPT or $PYC_DAEMON_SCRIPT"
    sleep 60
  fi

  # An unclean exit will decrement our restart limit count
  if [ $EXIT_CODE -gt 0 ]; then
    COUNT=`expr $COUNT - 1`
    echo "Unclean exit. Remaining daemon restart count is now $COUNT"
  else
    echo "Clean exit. Not decrementing restart count"
  fi

  # Exit out loop and reboot
  if [ $COUNT -eq 0 ]; then
    break
  fi

  sleep 2
done

# We allow only so many restarts until we flat out reboot to fix any potential problems
echo "Rebooting!"
/sbin/reboot -f
