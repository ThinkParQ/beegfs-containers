#!/usr/bin/python3
import os
import sys
import logging
import subprocess

logging.basicConfig(level=logging.DEBUG, format='%(asctime)s %(levelname)s [%(filename)s]: %(message)s')
log = logging.getLogger()

conn_auth_file_path = "/etc/beegfs/connAuthFile"
beegfs_service_type = ""
store_beegfs_directory = ""

# Pass connauthfile secret as environment vaiable 
if 'CONN_AUTH_FILE_DATA' in os.environ:
    with open(conn_auth_file_path, "w") as fp:
        conn_auth_val = os.environ.get('CONN_AUTH_FILE_DATA')
        fp.write(conn_auth_val.replace('\\n', '\n') + '\n')

# Determine any commands that will be used to setup BeeGFS targets:
beegfs_setup = []
for key, value in os.environ.items():
    if "BEEGFS_SERVICE" in key: 
        if value == "beegfs-mgmtd":
            beegfs_service_type = value
            store_beegfs_directory = "storeMgmtdDirectory"
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
    if store_beegfs_directory in arg:
        beegfs_targets = arg.split("=")[1].split(",")

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