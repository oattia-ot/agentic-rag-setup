#!/bin/bash
set -e

echo "Checking Docker..."

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose plugin is missing."
  exit 1
fi

echo "Checking available memory..."

MEM_GB=$(free -g | awk '/Mem:/ {print $2}')

if [ "$MEM_GB" -lt 8 ]; then
  echo "At least 8GB RAM is recommended."
fi

echo "Checking free disk..."

FREE_GB=$(df -BG . | awk 'NR==2 {gsub("G","",$4); print $4}')

if [ "$FREE_GB" -lt 20 ]; then
  echo "At least 20GB free space is recommended."
fi

echo "Prerequisites check completed."
