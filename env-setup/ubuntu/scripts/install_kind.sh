#!/usr/bin/env bash
set -euo pipefail

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
  "https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-linux-$ARCH" \
  --output "$KIND_BINARY"
install -o root -g root -m 0755 "$KIND_BINARY" /usr/local/bin/kind
kind version

KIND_NODE_IMAGE="kindest/node:$KIND_NODE_VERSION"
docker pull "$KIND_NODE_IMAGE"
