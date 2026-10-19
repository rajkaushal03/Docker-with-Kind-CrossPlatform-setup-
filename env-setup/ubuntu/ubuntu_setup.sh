#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "This script must run as root inside the Ubuntu container." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/configure/env.conf"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Environment configuration file not found: $CONFIG_FILE" >&2
  exit 1
fi

# Normalize possible Windows CRLF before sourcing the shell-compatible config.
source <(sed 's/\r$//' "$CONFIG_FILE")

required_variables=(
  UBUNTU_IMAGE
  UBUNTU_CONTAINER_NAME
  UBUNTU_SETUP_FILE_NAME
  UBUNTU_CONTAINER_SCRIPTS_PATH
  DOCKER_SOCKET_PATH
  KIND_VERSION
  KIND_NODE_VERSION
  LINKWISE_IMAGE_NAME
  LINKWISE_IMAGE_TAG
  LINKWISE_CONTAINER_NAME
  LINKWISE_HOST_PORT
  LINKWISE_CONTAINER_PORT
  APP_NODE_VERSION
  APP_REACT_VERSION
  APP_VITE_VERSION
  APP_REACT_PLUGIN_VERSION
  APP_FIREBASE_APP_VERSION
  APP_FIREBASE_AUTH_VERSION
)

for variable in "${required_variables[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    echo "Required setting '$variable' is missing from $CONFIG_FILE" >&2
    exit 1
  fi
done

export KIND_VERSION KIND_NODE_VERSION
export LINKWISE_IMAGE_NAME LINKWISE_IMAGE_TAG LINKWISE_CONTAINER_NAME
export LINKWISE_HOST_PORT LINKWISE_CONTAINER_PORT
export APP_NODE_VERSION APP_REACT_VERSION APP_VITE_VERSION
export APP_REACT_PLUGIN_VERSION APP_FIREBASE_APP_VERSION APP_FIREBASE_AUTH_VERSION

for script in install_utilities.sh install_kind.sh deploy_linkwise_ui.sh verify_environment.sh; do
  script_path="$SCRIPTS_DIR/$script"
  if [[ ! -f "$script_path" ]]; then
    echo "Required setup script not found: $script_path" >&2
    exit 1
  fi
done

bash "$SCRIPTS_DIR/install_utilities.sh"

if ! docker info >/dev/null 2>&1; then
  echo "The Docker CLI is installed, but cannot access the host Docker daemon through $DOCKER_SOCKET_PATH." >&2
  echo "Check Docker Desktop's Linux-container mode and the socket mount." >&2
  exit 1
fi

bash "$SCRIPTS_DIR/install_kind.sh"
bash "$SCRIPTS_DIR/deploy_linkwise_ui.sh"
bash "$SCRIPTS_DIR/verify_environment.sh"

echo "Ubuntu utilities and kind are ready."
echo "Linkwise UI is running in detached mode at http://localhost:$LINKWISE_HOST_PORT"
