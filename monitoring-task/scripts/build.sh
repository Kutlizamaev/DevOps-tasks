#!/usr/bin/env bash

set -Eeuo pipefail

TAG="latest"

while getopts "t:" opt; do
    case "$opt" in
        t)
            TAG="$OPTARG"
            ;;
        *)
            echo "Использование: $0 [-t tag]"
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

IMAGE="fanil-monitoring-app:${TAG}"

echo "========================================"
echo "Building image: ${IMAGE}"
echo "========================================"

docker build \
    -t "$IMAGE" \
    .

echo
echo "========================================"
echo "Loading image into Minikube..."
echo "========================================"

minikube image load "$IMAGE"

echo
echo "Image ${IMAGE} successfully built and loaded."
