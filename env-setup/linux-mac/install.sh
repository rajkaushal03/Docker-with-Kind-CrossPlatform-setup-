#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
UBUNTU_SCRIPTS_DIR="$PROJECT_DIR/ubuntu"
ENVIRONMENT_CONFIG="$UBUNTU_SCRIPTS_DIR/configure/env.conf"

if [[ ! -f "$ENVIRONMENT_CONFIG" ]]; then
  echo "Environment configuration file not found at '$ENVIRONMENT_CONFIG'." >&2
  exit 1
fi
source <(sed 's/\r$//' "$ENVIRONMENT_CONFIG")

for setting in UBUNTU_IMAGE UBUNTU_CONTAINER_NAME UBUNTU_SETUP_FILE_NAME \
  UBUNTU_CONTAINER_SCRIPTS_PATH DOCKER_SOCKET_PATH; do
  if [[ -z "${!setting:-}" ]]; then
    echo "Required setting '$setting' is missing from '$ENVIRONMENT_CONFIG'." >&2
    exit 1
  fi
done

UBUNTU_CONTAINER="$UBUNTU_CONTAINER_NAME"
UBUNTU_SETUP_SCRIPT="$UBUNTU_SCRIPTS_DIR/$UBUNTU_SETUP_FILE_NAME"
UBUNTU_SETUP_CONTAINER_PATH="$UBUNTU_CONTAINER_SCRIPTS_PATH/$UBUNTU_SETUP_FILE_NAME"

if [[ ! -f "$UBUNTU_SETUP_SCRIPT" ]]; then
  echo "Shared Ubuntu setup script not found at '$UBUNTU_SETUP_SCRIPT'." >&2
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
    --mount "type=bind,source=$UBUNTU_SCRIPTS_DIR,target=$UBUNTU_CONTAINER_SCRIPTS_PATH,readonly" \
    --mount "type=bind,source=$DOCKER_SOCKET_PATH,target=$DOCKER_SOCKET_PATH" \
    --publish 30080:30080 \
    --publish 30443:30443 \
    "$UBUNTU_IMAGE" sleep infinity
else
  if [[ "$(docker inspect --format '{{.State.Running}}' "$UBUNTU_CONTAINER")" != "true" ]]; then
    docker start "$UBUNTU_CONTAINER"
  fi

  if ! docker exec "$UBUNTU_CONTAINER" test -f "$UBUNTU_SETUP_CONTAINER_PATH"; then
    echo "Existing Ubuntu container is missing the mounted setup script; recreating it with the current ubuntu folder."
    docker rm --force "$UBUNTU_CONTAINER"
    docker run --detach \
      --name "$UBUNTU_CONTAINER" \
      --label com.example.docker-k8s-setup=true \
      --mount "type=bind,source=$UBUNTU_SCRIPTS_DIR,target=$UBUNTU_CONTAINER_SCRIPTS_PATH,readonly" \
      --mount "type=bind,source=$DOCKER_SOCKET_PATH,target=$DOCKER_SOCKET_PATH" \
      "$UBUNTU_IMAGE" sleep infinity
  fi
fi

CONTAINER_SETUP_COMMAND='
set -euo pipefail
setup_dir="$(mktemp -d)"
trap '\''rm -rf "$setup_dir"'\'' EXIT
cp -R "$UBUNTU_CONTAINER_SCRIPTS_PATH/." "$setup_dir/"
find "$setup_dir" -type f \( -name '\''*.sh'\'' -o -name '\''*.conf'\'' \) -exec sed -i '\''s/\r$//'\'' {} +
bash "$setup_dir/$UBUNTU_SETUP_FILE_NAME"
'

docker exec \
  --env "UBUNTU_SETUP_FILE_NAME=$UBUNTU_SETUP_FILE_NAME" \
  --env "UBUNTU_CONTAINER_SCRIPTS_PATH=$UBUNTU_CONTAINER_SCRIPTS_PATH" \
  "$UBUNTU_CONTAINER" \
  bash -lc "$CONTAINER_SETUP_COMMAND"

echo "Setup complete. Ubuntu is running in '$UBUNTU_CONTAINER'."
echo "Linkwise UI is running at http://localhost:$LINKWISE_HOST_PORT"
