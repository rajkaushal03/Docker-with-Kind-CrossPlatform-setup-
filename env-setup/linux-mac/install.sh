#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
UBUNTU_CONTAINER="docker-k8s-ubuntu"
UBUNTU_IMAGE="ubuntu:24.04"
UBUNTU_SCRIPTS_DIR="$PROJECT_DIR/ubuntu"
UBUNTU_SETUP_SCRIPT="$UBUNTU_SCRIPTS_DIR/ubuntu_setup.sh"

if [[ ! -f "$UBUNTU_SETUP_SCRIPT" ]]; then
  echo "Shared Ubuntu setup script not found at '$UBUNTU_SETUP_SCRIPT'." >&2
  echo "Ensure ubuntu/ is alongside linux-mac/ and windows/." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI was not found. Run ./prerequisite.sh first." >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon is not ready. Run ./prerequisite.sh and start Docker Desktop/Engine." >&2
  exit 1
fi

docker pull "$UBUNTU_IMAGE"

if ! docker container inspect "$UBUNTU_CONTAINER" >/dev/null 2>&1; then
  docker run --detach \
    --name "$UBUNTU_CONTAINER" \
    --label com.example.docker-k8s-setup=true \
    --mount "type=bind,source=$UBUNTU_SCRIPTS_DIR,target=/opt/docker-k8s-setup,readonly" \
    --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
    "$UBUNTU_IMAGE" sleep infinity
else
  if [[ "$(docker inspect --format '{{.State.Running}}' "$UBUNTU_CONTAINER")" != "true" ]]; then
    docker start "$UBUNTU_CONTAINER"
  fi

  if ! docker exec "$UBUNTU_CONTAINER" test -f /opt/docker-k8s-setup/ubuntu_setup.sh; then
    echo "Existing Ubuntu container is missing the mounted setup script; recreating it with the current ubuntu folder."
    docker rm --force "$UBUNTU_CONTAINER"
    docker run --detach \
      --name "$UBUNTU_CONTAINER" \
      --label com.example.docker-k8s-setup=true \
      --mount "type=bind,source=$UBUNTU_SCRIPTS_DIR,target=/opt/docker-k8s-setup,readonly" \
      --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
      "$UBUNTU_IMAGE" sleep infinity
  fi
fi

docker exec "$UBUNTU_CONTAINER" bash /opt/docker-k8s-setup/ubuntu_setup.sh

echo "Setup complete. Ubuntu is running in '$UBUNTU_CONTAINER'."
echo "Linkwise UI is running at http://localhost:5000"
