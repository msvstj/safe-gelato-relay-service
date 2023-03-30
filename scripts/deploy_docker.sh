#!/bin/bash

set -euo pipefail

# Workflow run number
export BUILD_NUMBER=$GITHUB_RUN_NUMBER
# strip the first char as that should always be "v" (as tags should be in the format "vX.X.X")
description="$(git describe --tags --always)"
export VERSION=${description:1}

echo "Trigger docker build and upload for version $VERSION ($BUILD_NUMBER)"

if [ "$1" = "develop" -o "$1" = "main" ]; then
    cache_tag="$1"
else
    cache_tag="staging"
fi

cached_runtime_image_id="$DOCKERHUB_ORG/$DOCKERHUB_PROJECT:$cache_tag"
runtime_image_id="$DOCKERHUB_ORG/$DOCKERHUB_PROJECT:$1"

# Load cached runtime image
docker pull $cached_runtime_image_id || true
# Rebuild runtime image if required
docker build \
    --cache-from $cached_runtime_image_id \
    -t $runtime_image_id \
    -f Dockerfile \
    --build-arg VERSION --build-arg BUILD_NUMBER \
    .

# Push runtime images to remote repository
docker push $runtime_image_id

# If release, set latest docker tag
case $1 in v*)
    latest_image_id="$DOCKERHUB_ORG/$DOCKERHUB_PROJECT:latest"
    docker tag $runtime_image_id $latest_image_id
    docker push $latest_image_id
esac