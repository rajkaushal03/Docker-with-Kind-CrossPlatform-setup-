#!/usr/bin/env bash
set -euo pipefail

KIND_NODE_IMAGE="kindest/node:$KIND_NODE_VERSION"
LINKWISE_IMAGE="$LINKWISE_IMAGE_NAME:$LINKWISE_IMAGE_TAG"

docker --version
kind version
docker image inspect "$KIND_NODE_IMAGE" >/dev/null
docker image inspect "$LINKWISE_IMAGE" >/dev/null

LINKWISE_STATE="$(docker inspect --format '{{.State.Running}}' "$LINKWISE_CONTAINER_NAME")"
if [[ "$LINKWISE_STATE" != "true" ]]; then
  echo "Linkwise UI container '$LINKWISE_CONTAINER_NAME' is not running." >&2
  exit 1
fi

echo "Application build versions: Node.js $APP_NODE_VERSION, React $APP_REACT_VERSION, Vite $APP_VITE_VERSION."
echo "Firebase SDK versions: app $APP_FIREBASE_APP_VERSION, auth $APP_FIREBASE_AUTH_VERSION."
echo "Verified images and running Linkwise UI container."
