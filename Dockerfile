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

# Using multi-stage docker with the same base image for all daemons.

FROM debian:10.12-slim AS base
ARG DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/beegfs/sbin/:${PATH}"
ARG BEEGFS_VERSION="7.3.1"
ENV BEEGFS_VERSION=$BEEGFS_VERSION

# Enable RDMA support
RUN apt-get update && apt-get install rdma-core  infiniband-diags perftest -y && rm -rf /var/lib/apt/lists/*

# Install Required Utilities:
# Notes:
# 1) The following packages enable: ps (procps), lsmod (kmod), firewall mgmt (iptables), mkfs.xfs (xfsprogs), ip CLI utilities (iproute2).
# 2) Not installing ethtool as it should be included in the base image. 
# 3) gnupg2 is required for apt-key and ca-certificates is required to connect to the BeeGFS repo over HTTPS.
# 4) wget is only used to download the BeeGFS GPG key and repository file.
RUN apt-get update && apt-get install procps kmod iptables xfsprogs iproute2 gnupg2 ca-certificates wget -y && rm -rf /var/lib/apt/lists/*

# Install Optional Utilities:
RUN apt-get update && apt-get install nano vim dstat sysstat -y && rm -rf /var/lib/apt/lists/*

# Install Beegfs binaries from the public repo.
RUN wget -q https://www.beegfs.io/release/beegfs_$BEEGFS_VERSION/gpg/GPG-KEY-beegfs -O- | apt-key add -
RUN wget https://www.beegfs.io/release/beegfs_$BEEGFS_VERSION/dists/beegfs-buster.list -P /etc/apt/sources.list.d/

# Container expects the desired BeeGFS service to be specified as part of the run command: 
# Example: docker run -it beegfs/beegfs-mgmtd:7.3.0 beegfs-mgmtd storeMgmtdDirectory=/mnt/beegfs-mgmtd\
COPY servers/start.sh /root/start.sh
COPY servers/init.py /root/init.py
RUN chmod +x /root/start.sh /root/init.py
# Make a default directory where BeeGFS services can store data:
RUN mkdir -p /data/beegfs


# Build beegfs-mgmtd docker image with `docker build -t repo/image-name  --target beegfs-mgmtd .`  
FROM base AS beegfs-mgmtd
ARG BEEGFS_SERVICE="beegfs-mgmtd"
ENV BEEGFS_SERVICE=$BEEGFS_SERVICE
RUN apt-get update && apt-get install $BEEGFS_SERVICE libbeegfs-ib -y && rm -rf /var/lib/apt/lists/* 
ENTRYPOINT ["/root/start.sh"]


# Build beegfs-meta docker image with `docker build -t repo/image-name  --target beegfs-meta .`  
FROM base AS beegfs-meta
ARG BEEGFS_SERVICE="beegfs-meta"
ENV BEEGFS_SERVICE=$BEEGFS_SERVICE
RUN apt-get update && apt-get install $BEEGFS_SERVICE libbeegfs-ib -y && rm -rf /var/lib/apt/lists/*
RUN rm -rf /etc/beegfs/*conf
ENTRYPOINT ["/root/start.sh"]


# Build beegfs-storage docker image with `docker build -t repo/image-name  --target beegfs-storage .`  
FROM base AS beegfs-storage
ARG BEEGFS_SERVICE="beegfs-storage"
ENV BEEGFS_SERVICE=$BEEGFS_SERVICE
RUN apt-get update && apt-get install $BEEGFS_SERVICE libbeegfs-ib -y && rm -rf /var/lib/apt/lists/*
RUN rm -rf /etc/beegfs/*conf
ENTRYPOINT ["/root/start.sh"]


# Build beegfs-all docker image with `docker build -t repo/image-name  --target beegfs-all .`  
FROM base AS beegfs-all
ARG BEEGFS_SERVICE="beegfs-all"
RUN apt-get update && apt-get install libbeegfs-ib beegfs-mgmtd beegfs-meta beegfs-storage -y && rm -rf /var/lib/apt/lists/*
RUN rm -rf /etc/beegfs/*conf
ENTRYPOINT ["/root/start.sh"]
# arguments passed as commands in docker run will be passed as arguments to start.sh inturn passed to BeeGFS service.
