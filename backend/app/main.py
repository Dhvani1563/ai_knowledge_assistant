import logging
import threading

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import models  # noqa: F401 — registers all models on Base.metadata
from .api.routes import auth, documents, chat
from .core.config import settings
from .core.database import Base, engine
from .services import vector_store

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Archive — AI Knowledge Assistant API",
    description="Upload documents, ask questions, get cited answers (RAG).",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins.split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _warm_up_models() -> None:
    """Load the embedding model + classifier in the background so the first
    upload/question isn't slow."""
    try:
        from .services.embedder import get_model
        from .ml.question_classifier import classify_question
        get_model()
        classify_question("warm up")
        logger.info("Embedding model and classifier ready.")
    except Exception:  # noqa: BLE001
        logger.exception("Model warm-up failed (will retry on first use).")


@app.on_event("startup")
def on_startup():
    Base.metadata.create_all(bind=engine)     # PostgreSQL tables
    vector_store.ensure_collection()          # Qdrant collection + payload indexes
    threading.Thread(target=_warm_up_models, daemon=True).start()
    logger.info("Startup complete.")


@app.get("/health")
def health_check():
    return {"status": "ok", "vector_db": "ok" if vector_store.is_healthy() else "unreachable"}


app.include_router(auth.router, prefix="/api/v1")
app.include_router(documents.router, prefix="/api/v1")
app.include_router(chat.router, prefix="/api/v1")
