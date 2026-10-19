#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ENVIRONMENT_CONFIG="$PROJECT_DIR/ubuntu/configure/env.conf"

if [[ ! -f "$ENVIRONMENT_CONFIG" ]]; then
  echo "Environment configuration file not found: '$ENVIRONMENT_CONFIG'." >&2
  exit 1
fi
source <(sed 's/\r$//' "$ENVIRONMENT_CONFIG")

for setting in UBUNTU_IMAGE UBUNTU_CONTAINER_NAME KIND_NODE_VERSION \
  LINKWISE_IMAGE_NAME LINKWISE_IMAGE_TAG LINKWISE_CONTAINER_NAME; do
  if [[ -z "${!setting:-}" ]]; then
    echo "Required setting '$setting' is missing from '$ENVIRONMENT_CONFIG'." >&2
    exit 1
  fi
done

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI was not found. Nothing can be cleaned up." >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "Cannot connect to Docker. Start Docker Desktop/Engine and retry." >&2
  exit 1
fi

for container in "$LINKWISE_CONTAINER_NAME"  "$UBUNTU_CONTAINER_NAME"; do
  if docker container inspect "$container" >/dev/null 2>&1; then
    state="$(docker inspect --format '{{.State.Running}}' "$container")" || {
      echo "Failed to inspect container '$container'." >&2
      exit 1
    }
    if [[ "$state" == "true" ]]; then
      docker stop "$container"
    fi
    docker rm "$container"
    echo "Removed container '$container'."
  else
    echo "Container '$container' is not present."
  fi
done

for image in \
  "$LINKWISE_IMAGE_NAME:$LINKWISE_IMAGE_TAG" \
  nginx:stable \
  "kindest/node:$KIND_NODE_VERSION" \
  "$UBUNTU_IMAGE"; do
  if docker image inspect "$image" >/dev/null 2>&1; then
    docker image rm "$image"
    echo "Removed image '$image'."
  else
    echo "Image '$image' is not present."
  fi
done

echo "Cleanup complete. Docker itself was left installed."
