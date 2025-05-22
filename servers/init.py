#!/usr/bin/python3

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

import os
import sys
import logging
import subprocess

logging.basicConfig(level=logging.DEBUG, format='%(asctime)s %(levelname)s [%(filename)s]: %(message)s')
log = logging.getLogger()

beegfs_service_type = ""
store_beegfs_directory = ""
beegfs_database_path = ""

if 'BEEGFS_VERSION' not in os.environ:
    log.critical("The BEEGFS_VERSION environment variable is not set. This is required to determine the BeeGFS version.")
    sys.exit(1)

beegfs_major_version = int(os.environ.get('BEEGFS_VERSION')[0])
log.info(f"BeeGFS version: {beegfs_major_version}")


file_env_mapping = {
    'CONN_AUTH_FILE_DATA': "/etc/beegfs/conn.auth",
    'BEEGFS_LICENSE_FILE_DATA': "/etc/beegfs/license.pem",
    'TLS_KEY_FILE_DATA': "/etc/beegfs/key.pem",
    'TLS_CERT_FILE_DATA': "/etc/beegfs/cert.pem"
}

# Check if the environment variables are set and write their values to the corresponding files.
for env_var, file_path in file_env_mapping.items():
    if env_var in os.environ:
        with open(file_path, "w") as fp:
            file_data = os.environ.get(env_var)
            fp.write(file_data.replace('\\n', '\n') + '\n')

# Determine any commands that will be used to setup BeeGFS targets:
beegfs_setup = []
for key, value in os.environ.items():
    if "BEEGFS_SERVICE" in key: 
        if value == "beegfs-mgmtd":
            beegfs_service_type = value
            if beegfs_major_version == 7:
                store_beegfs_directory = "storeMgmtdDirectory"
            else:
                beegfs_database_path = "--db-file"
        if value == "beegfs-meta":
            beegfs_service_type = value
            store_beegfs_directory = "storeMetaDirectory"
        if value == "beegfs-storage":
            beegfs_service_type = value
            store_beegfs_directory = "storeStorageDirectory"                             
    if "beegfs_setup" in key:
        beegfs_setup.append(value)

if beegfs_service_type == "":
    log.critical("Unable to determine BeeGFS service type. Possibly the BEEGFS_SERVICE " \
                    "environment variable was not set in the Dockerfile, or is not supported yet.")
    sys.exit(1)


# Capture command line arguments that will be used to start BeeGFS:
beegfs_args = sys.argv[1:]

# Determine BeeGFS targets configured specified in command line arguments:
beegfs_targets=[]
for arg in beegfs_args:
    if store_beegfs_directory and store_beegfs_directory in arg:
        beegfs_targets = arg.split("=")[1].split(",")

# BeeGFS V8 management does not use a mount directory; instead, add the database file's basepath in beegfs_targets.
if '--db-file' in beegfs_args:
    if '--db-file=' in ' '.join(beegfs_args):
        beegfs_database_path = [arg.split('=')[1] for arg in beegfs_args if arg.startswith('--db-file=')][0]
    elif '--db-file' in beegfs_args:
        beegfs_database_path = beegfs_args[beegfs_args.index('--db-file') + 1]
    
    if os.path.exists(beegfs_database_path):
        log.info(f"BeeGFS Mgmtd database path {beegfs_database_path} already exists.")
    else:
        log.info(f"BeeGFS Mgmtd database path {beegfs_database_path} does not exist, creating it.")
        os.makedirs(os.path.dirname(beegfs_database_path), exist_ok=True)
    beegfs_targets = [os.path.dirname(beegfs_database_path)]

# If BeeGFS should be configured using the setup scripts, ensure setup commands were provided for all targets specified
# in the command line argument.

if len(beegfs_setup) > 0:
    log.info("At least one BeeGFS setup command was provided, attempting to configure BeeGFS targets using the setup script.")

    # Preflight checks:
    if len(beegfs_setup) != len(beegfs_targets):
        log.critical("The number of setup commands does not match the number of targets listed for " + store_beegfs_directory + ".\n"\
                    "BeeGFS setup commands provided as environment variable(s) 'beegfs_setup_*': " + str(beegfs_setup) + "\n"\
                    "BeeGFS targets in " + store_beegfs_directory + ": " + str(beegfs_targets))
        sys.exit(1)

    for target in beegfs_targets:
        found = False
        for setup in beegfs_setup:
            if target in setup:
                found = True
                break 
        if not found:
            log.critical("BeeGFS target '" + target + "' was included in " + store_beegfs_directory + " but there is not corresponding BeeGFS setup command.\n"\
                         "BeeGFS setup commands provided as environment variable(s) 'beegfs_setup_*': %s", beegfs_setup)
            sys.exit(1) 

    # Setup targets

    for target in beegfs_targets:
        for setup in beegfs_setup:
            if target in setup:
                if os.path.exists(target + "/alreadyInitByContainer"):
                    log.info(f"BeeGFS target {target} was already initialized since {target}/alreadyInitByContainer exists.")
                    break
                else:
                    # Without shell=True you will get "line 102: ${FORMAT_FILE_PATH}: ambiguous redirect"
                    setup_result = subprocess.run([setup], capture_output=True, shell=True, text=True)
                    
                    if setup_result.returncode != 0:
                        log.critical(f"Setting up BeeGFS target {target} using command '{setup}' failed. \n" \
                                     f"=== command === \n {setup_result.args} \n === stdout ===\n {setup_result.stdout}\n === stderr === \n {setup_result.stderr}")
                        exit(1)

                    with open(target + "/alreadyInitByContainer", "w") as f:
                        f.write("\n")
                    
                    log.info(f"Initialized BeeGFS target {target} and set {target}/alreadyInitByContainer to true.")                    

exit(0)

# TODO: Set storeFsUUID, note - "blkid -s UUID" can only be run from a privileged container.
