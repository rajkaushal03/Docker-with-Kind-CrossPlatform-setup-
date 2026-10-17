#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI was not found. Nothing can be cleaned up." >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "Cannot connect to Docker. Start Docker Desktop/Engine and retry." >&2
  exit 1
fi

for container in docker-k8s-linkwise-ui docker-k8s-nginx docker-k8s-ubuntu; do
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

for image in nidznd/linkwise-ui:latest nginx:stable kindest/node:v1.34.0 ubuntu:24.04; do
  if docker image inspect "$image" >/dev/null 2>&1; then
    docker image rm "$image"
    echo "Removed image '$image'."
  else
    echo "Image '$image' is not present."
  fi
done

echo "Cleanup complete. Docker itself was left installed."
