#!/bin/bash
set -e

cat > docker-compose.yml <<'EOF'
services:

  ollama:
    image: ollama/ollama
    container_name: ollama
    restart: unless-stopped
    ports:
      - "11434:11434"
    volumes:
      - ollama:/root/.ollama

  qdrant:
    image: qdrant/qdrant
    container_name: qdrant
    restart: unless-stopped
    ports:
      - "6333:6333"
    volumes:
      - qdrant:/qdrant/storage

  postgres:
    image: postgres:16
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: agentdb
      POSTGRES_USER: agent
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres:/var/lib/postgresql/data

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: unless-stopped
    ports:
      - "3000:8080"
    environment:
      OLLAMA_BASE_URL: http://ollama:11434
    depends_on:
      - ollama

  rag-agent:
    build: ./app
    container_name: rag-agent
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      OLLAMA_URL: http://ollama:11434
      QDRANT_URL: http://qdrant:6333
      POSTGRES_HOST: postgres
    depends_on:
      - ollama
      - qdrant
      - postgres

volumes:
  ollama:
  qdrant:
  postgres:
EOF

echo "docker-compose.yml generated."
