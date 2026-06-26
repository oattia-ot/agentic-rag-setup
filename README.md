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

## Tutorial 6: Exploring Qdrant's Dashboard

Goal: see what's actually inside your vector database, visually.

1. **Confirm Qdrant is reachable**:
   ```bash
   curl http://localhost:6333/healthz
   ```
2. **Open the dashboard** in a browser:
   ```text
   http://localhost:6333/dashboard
   ```
3. **List collections** — click "Collections" in the sidebar, or via API:
   ```bash
   curl http://localhost:6333/collections
   ```
   Right after Tutorial 1's setup this will be empty (`"collections": []`)
   since nothing has been ingested with real embedding logic yet.
4. **Inspect a collection** once one exists (see Tutorial 8):
   ```bash
   curl http://localhost:6333/collections/documents
   ```
   This shows vector count, vector size, and distance metric (e.g. cosine).
5. **Browse points visually**: in the dashboard, click into the collection
   name to see individual stored vectors and their payload (the original
   text chunk + metadata you attached during ingestion).

---

## Tutorial 7: Querying Qdrant Directly

Goal: run a similarity search against Qdrant without going through the
`rag-agent` at all — useful for debugging whether retrieval itself works
before blaming the LLM.

1. **Exec into the `rag-agent` container** (it already has `qdrant-client`
   installed per `requirements.txt`):
   ```bash
   docker compose exec rag-agent python3
   ```
2. **Run a quick search** from the Python prompt:
   ```python
   from qdrant_client import QdrantClient

   client = QdrantClient(host="qdrant", port=6333)
   print(client.get_collections())
   ```
3. **Embed a test query and search** (once you have a populated
   `documents` collection from Tutorial 8):
   ```python
   import requests

   def embed(text: str) -> list[float]:
       resp = requests.post(
           "http://ollama:11434/api/embeddings",
           json={"model": "nomic-embed-text", "prompt": text},
       )
       return resp.json()["embedding"]

   vector = embed("What does the contract say about termination?")
   hits = client.search(collection_name="documents", query_vector=vector, limit=3)
   for hit in hits:
       print(hit.score, hit.payload.get("text", "")[:200])
   ```
4. **Or skip Python and use the REST API directly**:
   ```bash
   curl -X POST http://localhost:6333/collections/documents/points/search \
     -H "Content-Type: application/json" \
     -d '{"vector": [0.01, 0.02, "...truncated..."], "limit": 3}'
   ```
   (In practice you'd generate that vector via the embed step above rather
   than typing it by hand.)

---

## Tutorial 8: Wiring Up Real Ingestion Into Qdrant

Goal: turn `app/ingest.py` from a file-name printer into something that
actually populates Qdrant, closing the gap flagged in Tutorial 2.

1. **Create the collection** (one-time, matching your embedding model's
   dimension — `nomic-embed-text` outputs 768-dim vectors):
   ```python
   from qdrant_client import QdrantClient
   from qdrant_client.models import VectorParams, Distance

   client = QdrantClient(host="qdrant", port=6333)
   client.recreate_collection(
       collection_name="documents",
       vectors_config=VectorParams(size=768, distance=Distance.COSINE),
   )
   ```
2. **Rewrite `app/ingest.py`** to load, chunk, embed, and upsert:
   ```python
   from pathlib import Path
   import uuid
   import requests
   from qdrant_client import QdrantClient
   from qdrant_client.models import PointStruct
   from langchain_community.document_loaders import UnstructuredFileLoader
   from langchain.text_splitter import RecursiveCharacterTextSplitter

   docs = Path("/documents")
   client = QdrantClient(host="qdrant", port=6333)
   splitter = RecursiveCharacterTextSplitter(chunk_size=800, chunk_overlap=100)

   def embed(text: str) -> list[float]:
       resp = requests.post(
           "http://ollama:11434/api/embeddings",
           json={"model": "nomic-embed-text", "prompt": text},
       )
       return resp.json()["embedding"]

   for file in docs.glob("*"):
       print(f"Processing {file}")
       chunks = splitter.split_documents(UnstructuredFileLoader(str(file)).load())
       points = [
           PointStruct(
               id=str(uuid.uuid4()),
               vector=embed(chunk.page_content),
               payload={"text": chunk.page_content, "source": file.name},
           )
           for chunk in chunks
       ]
       client.upsert(collection_name="documents", points=points)
       print(f"  -> upserted {len(points)} chunks")
   ```
3. **Rebuild and re-run ingestion**:
   ```bash
   docker compose build rag-agent
   docker compose up -d rag-agent
   ./scripts/06-ingest-documents.sh
   ```
4. **Verify** in the Qdrant dashboard (Tutorial 6) that `documents` now
   shows a non-zero vector count.

---

## Tutorial 9: Wiring Up Real Retrieval in `/chat`

Goal: make the `/chat` endpoint actually use what's in Qdrant, closing the
gap flagged in Tutorial 3.

1. **Update `app/main.py`** to embed the question, search Qdrant, and feed
   results to the LLM:
   ```python
   from fastapi import FastAPI
   import requests
   from qdrant_client import QdrantClient

   app = FastAPI()
   client = QdrantClient(host="qdrant", port=6333)

   def embed(text: str) -> list[float]:
       resp = requests.post(
           "http://ollama:11434/api/embeddings",
           json={"model": "nomic-embed-text", "prompt": text},
       )
       return resp.json()["embedding"]

   @app.get("/health")
   def health():
       return {"status": "UP"}

   @app.post("/chat")
   def chat(question: str):
       hits = client.search(
           collection_name="documents",
           query_vector=embed(question),
           limit=4,
       )
       context = "\n\n".join(h.payload.get("text", "") for h in hits)
       prompt = (
           f"Answer using only this context:\n{context}\n\n"
           f"Question: {question}"
       )
       resp = requests.post(
           "http://ollama:11434/api/generate",
           json={"model": "llama3.1:8b", "prompt": prompt, "stream": False},
       )
       return {"question": question, "answer": resp.json()["response"]}
   ```
2. **Rebuild and restart**:
   ```bash
   docker compose build rag-agent
   docker compose up -d rag-agent
   ```
3. **Test it against your real documents**:
   ```bash
   curl -X POST "http://localhost:8000/chat?question=Summarize+the+key+points"
   ```
   The `answer` field should now reflect content from your ingested files
   instead of the old placeholder string.

---

## Tutorial 10: Backing Up and Restoring Qdrant Data

Goal: snapshot your vector collection so you don't have to re-ingest and
re-embed everything from scratch if something goes wrong.

1. **Create a snapshot**:
   ```bash
   curl -X POST http://localhost:6333/collections/documents/snapshots
   ```
   Response includes a `name` field, e.g. `documents-2026-06-26-18-00-00.snapshot`.
2. **Download it** to your host machine:
   ```bash
   curl -o documents.snapshot \
     http://localhost:6333/collections/documents/snapshots/<snapshot-name>
   ```
3. **Restore on a fresh Qdrant instance** (e.g. after running Tutorial 5's
   cleanup):
   ```bash
   curl -X PUT \
     "http://localhost:6333/collections/documents/snapshots/upload" \
     -F "snapshot=@documents.snapshot"
   ```
4. **Verify the restore**:
   ```bash
   curl http://localhost:6333/collections/documents
   ```
   Confirm the `vectors_count` matches what you had before.

> 💾 Tip: since Qdrant's data also lives in a named Docker volume, a plain
> `docker compose down` (Tutorial 4, not `-v`) already preserves it across
> restarts. Snapshots matter most before a `09-cleanup.sh` run or before
> migrating to a different host.

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