#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install --yes --no-install-recommends \
  ca-certificates curl git vim less nano jq \
  iproute2 iputils-ping dnsutils procps tar gzip unzip docker.io

for command_name in curl git vim docker; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Utility installation did not provide '$command_name'." >&2
    exit 1
  fi
done
