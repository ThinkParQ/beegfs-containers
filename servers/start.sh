#!/bin/bash

# Copyright 2022 ThinkParQ GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
