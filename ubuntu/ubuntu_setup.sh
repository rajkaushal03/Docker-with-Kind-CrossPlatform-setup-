#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
NGINX_IMAGE="${NGINX_IMAGE:-nginx:stable}"
KIND_NODE_IMAGE="${KIND_NODE_IMAGE:-kindest/node:v1.34.0}"
NGINX_CONTAINER="docker-k8s-nginx"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "This script must run as root inside the Ubuntu container." >&2
  exit 1
fi

apt-get update
apt-get install --yes --no-install-recommends \
  ca-certificates curl git vim less nano jq \
  iproute2 iputils-ping dnsutils procps tar gzip unzip docker.io

if ! docker info >/dev/null 2>&1; then
  echo "The Docker CLI cannot access the host Docker daemon through /var/run/docker.sock." >&2
  echo "Check Docker Desktop's Linux-container mode and the socket mount." >&2
  exit 1
fi

ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  amd64|arm64) ;;
  *)
    echo "Unsupported architecture for kind: $ARCH" >&2
    exit 1
    ;;
esac

KIND_BINARY="$(mktemp)"
trap 'rm -f "$KIND_BINARY"' EXIT
curl --fail --location --silent --show-error \
  "https://kind.sigs.k8s.io/dl/latest/kind-linux-$ARCH" \
  --output "$KIND_BINARY"
install -o root -g root -m 0755 "$KIND_BINARY" /usr/local/bin/kind
kind version

docker pull "$KIND_NODE_IMAGE"
docker pull "$NGINX_IMAGE"

if docker container inspect "$NGINX_CONTAINER" >/dev/null 2>&1; then
  NGINX_STATE="$(docker inspect --format '{{.State.Running}}' "$NGINX_CONTAINER")"
  if [[ "$NGINX_STATE" != "true" ]]; then
    docker start "$NGINX_CONTAINER"
  fi
else
  docker run --detach \
    --name "$NGINX_CONTAINER" \
    --restart unless-stopped \
    --publish 3000:80 \
    "$NGINX_IMAGE"
fi

echo "Ubuntu utilities and kind are ready."
echo "Nginx is running in detached mode at http://localhost:3000"
