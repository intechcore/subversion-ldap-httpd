#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

IMAGE_NAME="subversion-ldap-httpd"
IMAGE_TAG="${1:-1.14.5}"

echo "[INFO] Building ${IMAGE_NAME}:${IMAGE_TAG}..."

docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

echo "[INFO] Done: ${IMAGE_NAME}:${IMAGE_TAG}"
