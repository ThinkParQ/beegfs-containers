#!/bin/sh

set -e -u -x

export BEEGFS_VERSION=$(git describe --tags --match '*.*' --abbrev=10)

export PATH_KEYS="~/.docker/trust/private"

echo "Set all the keys for docker trust and cosign"
set +x
echo $DOCKER_HUB_TOKEN|docker login --username $DOCKER_HUB_USER --password-stdin 
mkdir -p $PATH_KEYS
echo "${DOCKER_TRUST_SIGNER_PRIV_KEY}" > ${PATH_KEYS}/$SIGNER_KEY_NAME.key
echo "${COSIGN_PRIVATE_KEY}"> cosign.key
set -x

echo "Build all docker images"
docker build -t docker.io/beegfs/beegfs-all:${BEEGFS_VERSION} --build-arg BEEGFS_VERSION=${BEEGFS_VERSION}  --target beegfs-all .
docker build -t docker.io/beegfs/beegfs-mgmtd:${BEEGFS_VERSION} --build-arg BEEGFS_VERSION=${BEEGFS_VERSION}  --target beegfs-mgmtd .
docker build -t docker.io/beegfs/beegfs-meta:${BEEGFS_VERSION} --build-arg BEEGFS_VERSION=${BEEGFS_VERSION}  --target beegfs-meta .
docker build -t docker.io/beegfs/beegfs-storage:${BEEGFS_VERSION} --build-arg BEEGFS_VERSION=${BEEGFS_VERSION}  --target beegfs-storage .

echo "Tag the recent vesion as latest"
docker tag docker.io/beegfs/beegfs-all:${BEEGFS_VERSION} docker.io/beegfs/beegfs-all:latest
docker tag docker.io/beegfs/beegfs-mgmtd:${BEEGFS_VERSION} docker.io/beegfs/beegfs-mgmtd:latest
docker tag docker.io/beegfs/beegfs-meta:${BEEGFS_VERSION} docker.io/beegfs/beegfs-meta:latest
docker tag docker.io/beegfs/beegfs-storage:${BEEGFS_VERSION} docker.io/beegfs/beegfs-storage:latest

echo "Initally pushing all images"
docker push docker.io/beegfs/beegfs-all:${BEEGFS_VERSION}
docker push docker.io/beegfs/beegfs-mgmtd:${BEEGFS_VERSION}
docker push docker.io/beegfs/beegfs-meta:${BEEGFS_VERSION}
docker push docker.io/beegfs/beegfs-storage:${BEEGFS_VERSION}

docker push docker.io/beegfs/beegfs-all:latest
docker push docker.io/beegfs/beegfs-mgmtd:latest
docker push docker.io/beegfs/beegfs-meta:latest
docker push docker.io/beegfs/beegfs-storage:latest

echo "Signing image with Docker trust"
export DOCKER_CONTENT_TRUST=1
chmod 600 ${PATH_KEYS}/$SIGNER_KEY_NAME.key
docker trust key load ${PATH_KEYS}/$SIGNER_KEY_NAME.key

docker trust sign docker.io/beegfs/beegfs-all:${BEEGFS_VERSION}
docker trust sign docker.io/beegfs/beegfs-mgmtd:${BEEGFS_VERSION}
docker trust sign docker.io/beegfs/beegfs-meta:${BEEGFS_VERSION}
docker trust sign docker.io/beegfs/beegfs-storage:${BEEGFS_VERSION}

docker trust sign docker.io/beegfs/beegfs-all:latest
docker trust sign docker.io/beegfs/beegfs-mgmtd:latest
docker trust sign docker.io/beegfs/beegfs-meta:latest
docker trust sign docker.io/beegfs/beegfs-storage:latest


# COSIGN_PASSWORD environment variable is used by COSIGN_PRIVATE_KEY to sign the images
echo "Signing image with Cosign"
cosign sign --key cosign.key docker.io/beegfs/beegfs-all:${BEEGFS_VERSION}
cosign sign --key cosign.key docker.io/beegfs/beegfs-mgmtd:${BEEGFS_VERSION}
cosign sign --key cosign.key docker.io/beegfs/beegfs-meta:${BEEGFS_VERSION}
cosign sign --key cosign.key docker.io/beegfs/beegfs-storage:${BEEGFS_VERSION}

cosign sign --key cosign.key docker.io/beegfs/beegfs-all:latest
cosign sign --key cosign.key docker.io/beegfs/beegfs-mgmtd:latest
cosign sign --key cosign.key docker.io/beegfs/beegfs-meta:latest
cosign sign --key cosign.key docker.io/beegfs/beegfs-storage:latest

echo "${COSIGN_PUBLIC_KEY}"
