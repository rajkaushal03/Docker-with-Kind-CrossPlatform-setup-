#!/usr/bin/env bash
set -euo pipefail

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo "Docker is installed and its daemon is ready."
  exit 0
fi

OS="$(uname -s)"
case "$OS" in
  Linux)
    if ! command -v apt-get >/dev/null 2>&1; then
      echo "Automatic Docker installation is supported for Debian/Ubuntu only." >&2
      echo "Install Docker Engine for your distribution: https://docs.docker.com/engine/install/" >&2
      exit 1
    fi

    run_privileged() {
      if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
      elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
      else
        echo "Install Docker Engine as root or install sudo, then retry." >&2
        return 1
      fi
    }

    run_privileged apt-get update
    run_privileged apt-get install --yes docker.io
    if command -v systemctl >/dev/null 2>&1; then
      run_privileged systemctl enable --now docker
    elif command -v service >/dev/null 2>&1; then
      run_privileged service docker start
    fi
    ;;
  Darwin)
    if ! command -v brew >/dev/null 2>&1; then
      echo "Install Docker Desktop from https://docs.docker.com/desktop/setup/install/mac-install/ or install Homebrew, then rerun." >&2
      exit 1
    fi
    brew install --cask docker
    open -a Docker
    ;;
  *)
    echo "Unsupported operating system: $OS" >&2
    exit 1
    ;;
esac

echo "Waiting for the Docker daemon to become ready..."
for _ in $(seq 1 36); do
  if docker info >/dev/null 2>&1; then
    echo "Docker is installed and its daemon is ready."
    exit 0
  fi
  sleep 5
done

echo "Docker was installed, but its daemon is not ready or is not accessible to this user." >&2
if [[ "$OS" == "Linux" ]]; then
  echo "On Linux, grant your user Docker access (for example, add it to the docker group), sign out/in, and rerun this script." >&2
  echo "Note: membership in the docker group grants root-equivalent access." >&2
else
  echo "Start Docker Desktop, wait for it to finish starting, and rerun this script." >&2
fi
exit 1
