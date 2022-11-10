#!/bin/bash

echo "$(date --rfc-3339=ns) INFO [start.sh]: Attempting to configure and start the '$BEEGFS_SERVICE' with the following configuration:"
echo $@
echo "$(date --rfc-3339=ns) INFO [start.sh]: Checking and initializing BeeGFS targets if needed."

if ! /root/init.py $@; then
	echo "$(date --rfc-3339=ns) FATAL [start.sh]: An unrecoverable error was encountered while checking and initializing BeeGFS targets."
	exit 1
else
    export CONN_AUTH_FILE_CONFIG=""

    if [[ ! -z "${CONN_AUTH_FILE_DATA}" ]]; then
        CONN_AUTH_FILE_CONFIG="connAuthFile=/etc/beegfs/connAuthFile"
    fi

    echo "$(date --rfc-3339=ns) INFO [start.sh]: Attempting to start the BeeGFS '$BEEGFS_SERVICE' with arguments : $@ ${CONN_AUTH_FILE_CONFIG}"
    $BEEGFS_SERVICE $@ ${CONN_AUTH_FILE_CONFIG}
    
fi
exit 0
