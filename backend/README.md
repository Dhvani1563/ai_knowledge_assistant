# Archive — Backend (FastAPI RAG pipeline)

```
Flutter → FastAPI → load → chunk → embed → Qdrant
                                              ↓
Flutter ← answer + sources ← LLM ← prompt ← retriever ← classifier ← question
```

## The stack — what, why, how

| Layer | Choice | Why | Where |
|---|---|---|---|
| API | **FastAPI** | typed, async-friendly, free Swagger UI at `/docs` | `app/main.py`, `app/api/routes/` |
| PDF | **PyMuPDF** (`fitz`) | fast, reliable, true per-page text → exact citations | `services/document_loader.py` |
| DOCX | **python-docx** | paragraphs + tables | same |
| TXT / MD | plain read | grouped into ~3000-char "sections" for citations | same |
| Chunking | **LangChain `RecursiveCharacterTextSplitter`** (`langchain-text-splitters` only) | splits at paragraph → line → sentence → word; 1000 chars / 150 overlap | `services/chunker.py` |
| Embeddings | **`BAAI/bge-small-en-v1.5`** via **sentence-transformers** | 384-dim, ~130 MB, strong retrieval for its size, free, CPU-friendly | `services/embedder.py` |
| Vector DB | **Qdrant** | first-class payload filtering (per-user isolation), dashboard, production-oriented | `services/vector_store.py` |
| Retriever | plain Python | top-k → relevance threshold → de-dup | `services/retriever.py` |
| LLM | **Gemini** (free tier) — or OpenAI / Anthropic | switch with one env var, no code change | `services/llm_service.py` |
| ML routing | **TF-IDF + Logistic Regression** (scikit-learn) | classifies factual / summarization / comparison / retrieval; changes top-k *and* prompt | `ml/`, `services/rag_pipeline.py` |
| Metadata DB | **PostgreSQL** | users, documents, chats, messages | `models/` |
| Orchestration | plain Python first | you can read the whole pipeline in one file; add LangChain/LlamaIndex later only if it earns its place | `services/rag_pipeline.py` |

**Which LLM?** Start with Gemini: `LLM_PROVIDER=gemini` + a free key from
https://aistudio.google.com/apikey. The SDK is `google-genai`. Model names
change often — set `GEMINI_MODEL` to a current one from AI Studio (default
`gemini-2.5-flash`). To use OpenAI or Claude instead, change `LLM_PROVIDER`
and fill that provider's key.

## Setup (Docker)

```bash
cd backend
cp .env.example .env        # (Windows: copy .env.example .env)
# edit .env: GEMINI_API_KEY at minimum
docker compose down -v      # ONE-TIME: wipes old dev data (schema changed)
docker compose up --build
```
First boot takes a few minutes (Python packages + the ~130 MB embedding
model, cached in a Docker volume afterwards). Ready when you see
`Startup complete`.

- Swagger UI: http://localhost:8000/docs
- Health: http://localhost:8000/health → `{"status":"ok","vector_db":"ok"}`
- Qdrant dashboard: http://localhost:6333/dashboard (watch chunks appear after an upload!)

Optional: `docker compose exec api python -m app.ml.train_classifier` prints the
classifier's cross-validation accuracy.

## API

| Method | Endpoint | |
|---|---|---|
| POST | `/api/v1/auth/signup` · `/login` | email + password → JWT |
| POST | `/api/v1/auth/google` · `/facebook` | provider token → verified server-side → JWT |
| GET | `/api/v1/auth/me` | current user |
| POST | `/api/v1/documents/upload` | multipart; processed in the background |
| GET | `/api/v1/documents` · `/{id}` | status + live `stage` (poll this) |
| DELETE | `/api/v1/documents/{id}` | removes file, metadata **and vectors** |
| POST | `/api/v1/chat/message` | classify → retrieve → generate |
| GET/DELETE | `/api/v1/chat/sessions[/{id}]` | history |

## Build it incrementally (recommended order to *understand* it)

1. **Loader** — in a Python shell run `load_document("x.pdf","pdf")`; print pages.
2. **Chunker** — `chunk_pages(pages)`; look at sizes; change `CHUNK_SIZE`, compare.
3. **Embedder** — embed two similar sentences and one unrelated; compare cosine scores.
4. **Vector store** — upload via `/docs`, then inspect points in the Qdrant dashboard.
5. **Retriever** — call `retrieve("your question", user_id, 5)`; read the scores.
6. **LLM** — call `generate_answer` with a hand-written prompt.
7. **Pipeline** — read `rag_pipeline.py` top to bottom; it is ~80 lines.

## Tuning knobs (`.env`)

| Setting | Effect |
|---|---|
| `CHUNK_SIZE` / `CHUNK_OVERLAP` | bigger = more context per hit, less precise; re-upload docs after changing |
| `MIN_RELEVANCE` | higher = stricter ("not found" more often); lower = more (noisier) evidence |
| `EMBEDDING_MODEL` + `VECTOR_DIMENSION` | change together **and delete/re-upload documents** (vectors from different models aren't comparable). Upgrades: `bge-base-en-v1.5` (768), `bge-m3` (multilingual) |

## Known limitations / next upgrades (good interview talking points)
- Scanned PDFs have no text layer → add OCR (Tesseract / `ocrmypdf`).
- Retrieval is dense-only → add BM25 hybrid search + a cross-encoder reranker.
- Follow-ups use recent chat turns as context; query rewriting would improve them further.
- Ingestion runs in a FastAPI BackgroundTask → move to Celery/RQ + Redis for real load.
- Tables are created by `create_all()` → adopt Alembic migrations.
- No streaming yet → add SSE to stream tokens and the classifier label.
