#!/bin/bash
set -e

echo "Waiting for Ollama..."

until curl -s http://localhost:11434 >/dev/null
do
  sleep 5
done

docker exec ollama ollama pull llama3.1:8b
docker exec ollama ollama pull nomic-embed-text

echo "Models downloaded."
