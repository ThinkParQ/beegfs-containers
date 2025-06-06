# BeeGFS Docker Images 

## Overview 

This repository contains files needed to build and run BeeGFS Docker images. The
repository is laid out to support both server and client images, though only
server images exist today. For BeeGFS server services a single Dockerfile and
supporting files exists under `servers/` and the Docker build arg
`BEEGFS_SERVICE` is used to control what type of server service Docker image is
built.

Generally users will not need to build images themselves, and can just use the
pre-built images for each BeeGFS release hosted on [GitHub Container
Registry](https://github.com/orgs/ThinkParQ/packages?repo_name=beegfs-containers).
Refer to the BeeGFS doc section on [Running BeeGFS in
Containers](https://doc.beegfs.io/latest/advanced_topics/containers.html) for
how to get started.

### BeeGFS Server Images 

The default entrypoint is a `start.sh` bash script that will call an `init.py` Python script that handles setting up the targets if needed. To avoid reinitializing targets it
writes a `alreadyInitByContainer` file to each target and checks if that file exists before calling the setup script.

## Getting Started

The Docker Compose file under `examples/docker-compose.yml` is probably the easiest way to get started. Simply `cd` to the directory and run `docker-compose up` and images for all
server services will be built/tagged and containers started. By default two internal (private) Docker networks will be created which all containers will use to communicate.

***

## Building Docker Images

To just build the Docker images from the `servers/` directory run:

```
docker build -t beegfs-mgmtd:latest --target beegfs-mgmtd .
docker build -t beegfs-meta:latest --target beegfs-meta .
docker build -t beegfs-storage:latest --target beegfs-storage .
```

*** 

## Running Docker Images

These Docker images can be run as follows: 

#### Management: 

##### V8 Management
```
docker run --privileged \
    --env beegfs_setup_1="beegfs-mgmtd --init --db-file /mnt/mgmt_tgt_mgmt01/mgmtd.sqlite  --log-target stderr " \
    --env CONN_AUTH_FILE_DATA="myconnauthsecret" \
    -it beegfs-mgmtd:latest --db-file /mnt/mgmt_tgt_mgmt01/mgmtd.sqlite  --interfaces eth0,eth1  --log-target stderr --tls-disable true
```

##### V7 Management
```
docker run --privileged \
    --env beegfs_setup_1="beegfs-setup-mgmtd -p /mnt/mgmt_tgt_mgmt01 -C -S mgmt_tgt_mgmt01" \
    --env CONN_AUTH_FILE_DATA="myconnauthsecret" \
    -it beegfs-mgmtd:latest storeMgmtdDirectory=/mnt/mgmt_tgt_mgmt01 storeAllowFirstRunInit=false connInterfacesList=eth0,eth1
```


#### Metadata: 

```
docker run --privileged \
    --env beegfs_setup_1="beegfs-setup-meta -C -p /mnt/meta_01_tgt_0101 -s 1 -S meta_01" \
    --env CONN_AUTH_FILE_DATA="myconnauthsecret" \
    -it beegfs-meta:latest storeMetaDirectory=/mnt/meta_01_tgt_0101 storeAllowFirstRunInit=false connInterfacesList=eth0,eth1 sysMgmtdHost=beegfs-management
```

#### Storage:

```
docker run --privileged \
    --env beegfs_setup_1="beegfs-setup-storage -C -p /mnt/stor_01_tgt_101 -s 1 -S stor_01_tgt_101 -i 101" \
    --env beegfs_setup_2="beegfs-setup-storage -C -p /mnt/stor_01_tgt_102 -s 1 -S stor_01_tgt_101 -i 102" \
    --env CONN_AUTH_FILE_DATA="myconnauthsecret" \
    -it beegfs-storage:latest storeStorageDirectory=/mnt/stor_01_tgt_101,/mnt/stor_01_tgt_102 storeAllowFirstRunInit=false connInterfacesList=eth0,eth1 sysMgmtdHost=beegfs-management
```
***