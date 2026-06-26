#!/bin/bash
set -e

docker compose exec rag-agent python ingest.py
