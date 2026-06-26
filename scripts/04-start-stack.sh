#!/bin/bash
set -e

docker compose pull
docker compose build
docker compose up -d

echo "Stack started."
