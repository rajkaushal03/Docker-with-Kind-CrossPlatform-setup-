#!/usr/bin/env bash
set -euo pipefail

LINKWISE_IMAGE="$LINKWISE_IMAGE_NAME:$LINKWISE_IMAGE_TAG"

docker pull "$LINKWISE_IMAGE"

if docker container inspect "$LINKWISE_CONTAINER_NAME" >/dev/null 2>&1; then
  LINKWISE_STATE="$(docker inspect --format '{{.State.Running}}' "$LINKWISE_CONTAINER_NAME")"
  if [[ "$LINKWISE_STATE" != "true" ]]; then
    docker start "$LINKWISE_CONTAINER_NAME"
  fi
else
  docker run --detach \
    --name "$LINKWISE_CONTAINER_NAME" \
    --restart unless-stopped \
    --publish "$LINKWISE_HOST_PORT:$LINKWISE_CONTAINER_PORT" \
    "$LINKWISE_IMAGE"
fi
