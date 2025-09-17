#!/usr/bin/env bash
set -Eeuo pipefail

CONTAINER_NAME="msmtp_dev"
SSH_USER="devuser"
SSH_PORT=2222

usage() {
    echo "Usage: $0 [--root] [--stop]"
    echo
    echo "  --root   Connect as root instead of devuser"
    echo "  --stop   Stop and remove the container"
    exit 1
}

# Argument parsing
if [[ $# -gt 1 ]]; then
    usage
fi

if [[ $# -eq 1 ]]; then
    case "$1" in
        --root)
            SSH_USER="root"
            ;;
        --stop)
            echo "🛑 Stopping and removing container ${CONTAINER_NAME}..."
            docker compose down
            echo "✅ Container stopped and removed."
            exit 0
            ;;
        *)
            usage
            ;;
    esac
fi

echo "🚀 Starting container ${CONTAINER_NAME}..."
docker compose up -d --build

echo "⏳ Waiting for container to become 'healthy'..."
# Wait until the healthcheck passes
until [ "$(docker inspect --format='{{.State.Health.Status}}' ${CONTAINER_NAME} 2>/dev/null)" = "healthy" ]; do
    sleep 2
done

echo "✅ Container is ready. Connecting via SSH as ${SSH_USER}..."
ssh -o StrictHostKeyChecking=no -p ${SSH_PORT} ${SSH_USER}@localhost
