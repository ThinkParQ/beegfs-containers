FROM debian:10.12-slim
ARG DEBIAN_FRONTEND=noninteractive

# Enable RDMA support:
# Notes:
# 1) Adapted from https://bitbucket.ngage.netapp.com/projects/ESSOL-BB/repos/ansible-host/browse/roles/ib/defaults/main.yml
# 2) POC installed ibutils, but we don't do that in our standard Ansible deployment anymore. Not including for now.

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

# Setting the BeeGFS service and version later in the file.
# This ensures all services can use the same base layers and shortens build times.

ARG BEEGFS_VERSION="7.3.0"
ENV BEEGFS_VERSION=$BEEGFS_VERSION
ARG BEEGFS_SERVICE=""
ENV BEEGFS_SERVICE=$BEEGFS_SERVICE

# Download BeeGFS GPG key, package repos, then install BeeGFS:

RUN wget -q https://www.beegfs.io/release/beegfs_$BEEGFS_VERSION/gpg/GPG-KEY-beegfs -O- | apt-key add -
RUN wget https://www.beegfs.io/release/beegfs_$BEEGFS_VERSION/dists/beegfs-deb10.list -P /etc/apt/sources.list.d/
RUN apt-get update && apt-get install $BEEGFS_SERVICE libbeegfs-ib -y --allow-unauthenticated && rm -rf /var/lib/apt/lists/*

# Make a default directory where BeeGFS services can store data:
RUN mkdir -p /data/beegfs

# Add BeeGFS binaries and scripts to PATH
ENV PATH="/opt/beegfs/sbin/:${PATH}"

# Remove original /var/log and /etc/beegfs directories to avoid confusion when debugging:

RUN rm -rf /var/log
RUN rm -rf /etc/beegfs

# Container expects the desired BeeGFS service to be specified as part of the run command: 
# Example: docker run -it esole/beegfs-mgmtd:7.3.0 beegfs-mgmtd storeMgmtdDirectory=/data/beegfs\

COPY start.sh /root/start.sh
COPY init.py /root/init.py
RUN chmod +x /root/start.sh /root/init.py

# Note if we don't specify the entrypoint like this, any arguments to docker run won't be passed on.
ENTRYPOINT ["/root/start.sh"]
