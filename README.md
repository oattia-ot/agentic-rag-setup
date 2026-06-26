# Agentic RAG Stack — Tutorials

This stack runs Ollama, Qdrant, Postgres, Open WebUI, and a FastAPI `rag-agent`
service via Docker Compose. The five tutorials below walk through deploying
it, loading documents, talking to it, keeping it healthy, and tearing it
down.

**Assumed layout** (run all commands from this `agentic-rag/` folder, the one
containing `docker-compose.yml` and `app/`):

```text
agentic-rag/
├── scripts/
├── app/
│   ├── Dockerfile
│   ├── main.py
│   ├── ingest.py
│   └── requirements.txt
├── documents/
├── data/
└── docker-compose.yml
```

---

## Tutorial 1: First-Time Deployment

Goal: get every container up and the models pulled into Ollama.

1. **Check prerequisites** — confirms Docker, Compose, RAM, and disk space.
   ```bash
   ./scripts/01-prerequisites.sh
   ```
2. **Create the project structure** — makes `app/`, `documents/`, `data/` if
   they don't already exist.
   ```bash
   ./scripts/02-create-project.sh
   ```
3. **Generate `docker-compose.yml`** — writes the compose file defining
   `ollama`, `qdrant`, `postgres`, `open-webui`, and `rag-agent`.
   ```bash
   ./scripts/03-generate-files.sh
   ```
4. **Build and start the stack**:
   ```bash
   ./scripts/04-start-stack.sh
   ```
   This runs `docker compose pull`, `build`, and `up -d`. Confirm everything
   is running:
   ```bash
   docker ps
   ```
   You should see `ollama`, `qdrant`, `postgres`, `open-webui`, and
   `rag-agent` all `Up`.
5. **Download the models into Ollama**:
   ```bash
   ./scripts/05-download-models.sh
   ```
   This pulls `llama3.1:8b` (chat) and `nomic-embed-text` (embeddings) —
   expect this to take a few minutes on first run.
6. **Verify**:
   ```bash
   ./scripts/07-health-check.sh
   ```
   Look for `"status": "UP"` from the RAG API and a response from Ollama.

✅ Done — Open WebUI is at `http://localhost:3000`, the RAG API at
`http://localhost:8000`.

---

## Tutorial 2: Adding and Ingesting Your Own Documents

Goal: get your PDFs/Word docs into the pipeline.

1. **Drop files into the `documents/` folder**:
   ```bash
   cp ~/Downloads/*.pdf documents/
   cp ~/Downloads/*.docx documents/
   ```
   This folder is mounted into the `rag-agent` container at `/documents`.
2. **Run ingestion**:
   ```bash
   ./scripts/06-ingest-documents.sh
   ```
   This executes `app/ingest.py` inside the `rag-agent` container.
3. **Check what happened**:
   ```bash
   docker compose logs rag-agent --tail=50
   ```
   You'll see a `Processing <file>` line per document.

> ⚠️ **Current limitation:** `app/ingest.py` only lists and prints file
> names right now — it doesn't yet chunk, embed, or write anything into
> Qdrant. To make ingestion functional you'll need to extend it to:
> 1. Load each file with `pypdf` / `python-docx` / `unstructured`.
> 2. Split text into chunks (e.g. `langchain` text splitters).
> 3. Embed chunks via Ollama's `nomic-embed-text` model.
> 4. Upsert vectors into Qdrant with `qdrant-client`.
>
> Until that's added, Tutorial 3's `/chat` answers won't be grounded in your
> documents — see the note in Tutorial 3.

---

## Tutorial 3: Chatting With the Agent

Goal: send a question and get an answer, via the API or the UI.

**Option A — direct API call:**
```bash
curl -X POST "http://localhost:8000/chat?question=What+is+in+my+documents%3F"
```
Expected response shape:
```json
{
  "question": "What is in my documents?",
  "answer": "Agent implementation goes here"
}
```

> ⚠️ **Current limitation:** `app/main.py`'s `/chat` endpoint is a stub — it
> echoes the question back with a placeholder answer. To make it a real RAG
> endpoint, it needs to: embed the incoming question, query Qdrant for
> similar chunks, then pass those chunks + the question to the
> `llama3.1:8b` model via `langchain-ollama` (or `langgraph` if you want
> multi-step/agentic behavior) and return the generated answer.

**Option B — Open WebUI:**
1. Open `http://localhost:3000` in a browser.
2. Create an account on first visit (local-only, stored in the
   `open-webui` container).
3. Select the `llama3.1:8b` model from the model dropdown and chat directly
   with Ollama.

   Note: Open WebUI talks straight to Ollama, not to your `rag-agent`'s
   `/chat` endpoint — so it won't use your ingested documents either unless
   you wire up a custom Open WebUI "function"/pipeline pointing at port 8000.

---

## Tutorial 4: Health-Checking, Stopping, and Restarting

Goal: confidently bring the stack down and back up without losing data.

1. **Health check anytime**:
   ```bash
   ./scripts/07-health-check.sh
   ```
   Shows container status, Ollama's response, and the RAG API's `/health`.
2. **Stop the stack** (containers removed, data volumes kept):
   ```bash
   ./scripts/08-stop-stack.sh
   ```
   Equivalent to `docker compose down`.
3. **Restart later**:
   ```bash
   docker compose up -d
   ```
   Since `ollama`, `qdrant`, and `postgres` volumes persist, your pulled
   models and any data survive the restart.
4. **Quick sanity check after restart**:
   ```bash
   docker ps
   curl http://localhost:8000/health
   ```

---

## Tutorial 5: Full Cleanup / Reset

Goal: wipe everything and start fresh (e.g. after testing, or before a clean
re-deploy).

1. **Tear down and delete volumes**:
   ```bash
   ./scripts/09-cleanup.sh
   ```
   This runs `docker compose down -v` (removing the `ollama`, `qdrant`, and
   `postgres` volumes — you'll need to re-pull models afterward), plus
   `docker image prune -f` and `docker volume prune -f`.
2. **Confirm everything is gone**:
   ```bash
   docker ps -a
   docker volume ls
   ```
3. **Re-deploy from scratch** by repeating Tutorial 1.

> 🗑️ This is destructive: ingested vectors in Qdrant, Postgres data, and
> downloaded Ollama models are all deleted. Your files in `documents/` are
> untouched since that's a bind mount, not a named volume.

---

## Quick Reference

| Script | Purpose |
|---|---|
| `01-prerequisites.sh` | Check Docker, RAM, disk space |
| `02-create-project.sh` | Create folder structure |
| `03-generate-files.sh` | Generate `docker-compose.yml` |
| `04-start-stack.sh` | Pull, build, and start all containers |
| `05-download-models.sh` | Pull `llama3.1:8b` and `nomic-embed-text` into Ollama |
| `06-ingest-documents.sh` | Run `app/ingest.py` inside `rag-agent` |
| `07-health-check.sh` | Check container status and API health |
| `08-stop-stack.sh` | `docker compose down` |
| `09-cleanup.sh` | `docker compose down -v` + prune images/volumes |

| Service | URL |
|---|---|
| Open WebUI | http://localhost:3000 |
| RAG API | http://localhost:8000 |
| Qdrant dashboard | http://localhost:6333/dashboard |
| Ollama | http://localhost:11434 |
