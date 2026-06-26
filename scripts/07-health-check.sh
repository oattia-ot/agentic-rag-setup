#!/bin/bash

echo "Containers:"
docker ps

echo
echo "Ollama:"
curl http://localhost:11434

echo
echo "RAG API:"
curl http://localhost:8000/health
