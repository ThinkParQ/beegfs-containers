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

if [[ -z "${BEEGFS_VERSION}" ]]; then
    echo "$(date --rfc-3339=ns) FATAL [start.sh]: The BEEGFS_VERSION environment variable is not set. This is required to determine the BeeGFS version."
    exit 1
fi

beegfs_major_version=${BEEGFS_VERSION:0:1}
if ! [[ "$beegfs_major_version" =~ ^[0-9]+$ ]]; then
    echo "$(date --rfc-3339=ns) FATAL [start.sh]: The BEEGFS_VERSION environment variable does not start with a valid number."
    exit 1
fi

if ! /root/init.py $@; then
	echo "$(date --rfc-3339=ns) FATAL [start.sh]: An unrecoverable error was encountered while checking and initializing BeeGFS targets."
	exit 1
fi


export CONFIG=""
# Configure connection authentication file based on service type and BeeGFS version
if [[ ! -z "${CONN_AUTH_FILE_DATA}" ]]; then
    if [[ "${BEEGFS_SERVICE}" == "beegfs-mgmtd" && "${beegfs_major_version}" -ne 7 ]]; then
        CONFIG="${CONFIG} --auth-file /etc/beegfs/conn.auth"
    else
        CONFIG="${CONFIG} connAuthFile=/etc/beegfs/conn.auth"
    fi
fi

# Configure license and TLS files for mgmtd version 8 and above
if [[ "${BEEGFS_SERVICE}" == "beegfs-mgmtd" && "${beegfs_major_version}" -ne 7 ]]; then
    if [[ ! -z "${BEEGFS_LICENSE_FILE_DATA}" ]]; then
        CONFIG="${CONFIG} --license-cert-file /etc/beegfs/license.pem"
    fi

    if [[ ! -z "${TLS_KEY_FILE_DATA}" ]]; then
        CONFIG="${CONFIG} --tls-key-file /etc/beegfs/key.pem"
    fi

    if [[ ! -z "${TLS_CERT_FILE_DATA}" ]]; then
        CONFIG="${CONFIG} --tls-cert-file /etc/beegfs/cert.pem"
    fi
fi


echo "$(date --rfc-3339=ns) INFO [start.sh]: Attempting to start the BeeGFS '$BEEGFS_SERVICE' with arguments : $@ ${CONFIG}"
# Use exec to replace the shell process so the BeeGFS service will directly receive signals sent to the container.
# This is important so we can shutdown gracefully and correctly write anything out to disk (like node states).
exec $BEEGFS_SERVICE $@ ${CONFIG}
    

exit 0
