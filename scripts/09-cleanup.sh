#!/bin/bash
set -e

docker compose down -v

docker image prune -f
docker volume prune -f
