#!/bin/bash

echo "$(date --rfc-3339=ns) INFO [start.sh]: Attempting to configure and start the '$BEEGFS_SERVICE' with the following configuration:"
echo $@
echo "$(date --rfc-3339=ns) INFO [start.sh]: Checking and initializing BeeGFS targets if needed."

if ! /root/init.py $@; then
	echo "$(date --rfc-3339=ns) FATAL [start.sh]: An unrecoverable error was encountered while checking and initializing BeeGFS targets."
	exit 1
else
    CONN_AUTH_FILE=/etc/beegfs/connauthfile
    CONN_AUTH_CONFIG="connAuthFile=/etc/beegfs/connauthfile"
    
    # if connAuthFile is missing set connDisableAuthentication=true with a warning
    if [ ! -f "$CONN_AUTH_FILE" ]; then
        echo "$(date --rfc-3339=ns) WARNING [start.sh]: $CONN_AUTH_FILE does not exist. $BEEGFS_SERVICE starting without connection authentication.  Possibly the CONN_AUTH_FILE_DATA environment variable was not passed while executing docker run. Setting connDisableAuthentication=true to continue without authentication."
        CONN_AUTH_CONFIG="connDisableAuthentication=true"
    fi
    
	echo "$(date --rfc-3339=ns) INFO [start.sh]: Attempting to start the BeeGFS '$BEEGFS_SERVICE'."
	$BEEGFS_SERVICE $CONN_AUTH_CONFIG  $@ 
fi
exit 0
