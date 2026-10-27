import logging
import threading

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from . import models  # noqa: F401 — registers all models on Base.metadata
from .api.routes import auth, documents, chat, security
from .core.config import settings
from .core.database import Base, engine
from .services import vector_store
from .services.file_security import check_encryption_key

logging.basicConfig(level=logging.INFO)
# httpx logs full request URLs at INFO level, which would print Facebook
# tokens (and the app secret) into the console and hosted logs.
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Archive — AI Knowledge Assistant API",
    description="Upload documents, ask questions, get cited answers (RAG).",
    version="3.0.0",
    # In production set ENABLE_DOCS=false so strangers can't browse your API map.
    docs_url="/docs" if settings.enable_docs else None,
    redoc_url="/redoc" if settings.enable_docs else None,
    openapi_url="/openapi.json" if settings.enable_docs else None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins.split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"   # browsers must not guess content types
    response.headers["X-Frame-Options"] = "DENY"             # cannot be embedded in another site's frame
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Cache-Control"] = "no-store"           # tokens and private data are never cached
    return response


# `create_all` only creates MISSING tables; it never adds columns to tables
# that already exist. These statements add the newer columns safely (each is
# a no-op when the column is already there), so your existing database keeps
# working without a manual migration.
_LIGHT_MIGRATIONS = [
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR",
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS oauth_provider VARCHAR",
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS oauth_id VARCHAR",
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url VARCHAR",
    "ALTER TABLE users ALTER COLUMN email DROP NOT NULL",
    "ALTER TABLE users ALTER COLUMN hashed_password DROP NOT NULL",
    "ALTER TABLE documents ADD COLUMN IF NOT EXISTS stage VARCHAR",
    "ALTER TABLE documents ADD COLUMN IF NOT EXISTS is_encrypted BOOLEAN NOT NULL DEFAULT FALSE",
    "ALTER TABLE documents ADD COLUMN IF NOT EXISTS flagged_chunks INTEGER NOT NULL DEFAULT 0",
]


def _apply_light_migrations() -> None:
    for statement in _LIGHT_MIGRATIONS:
        try:
            with engine.begin() as conn:
                conn.execute(text(statement))
        except Exception as exc:  # noqa: BLE001
            logger.warning("Migration step skipped (%s): %s", statement, exc)


def _check_security_config() -> None:
    production = settings.environment.lower() == "production"

    weak_secret = settings.jwt_secret_key in ("", "dev-secret-change-me") or len(settings.jwt_secret_key) < 32
    if weak_secret:
        message = "JWT_SECRET_KEY is missing, default, or shorter than 32 characters. Anyone who knows it can forge logins."
        if production:
            raise RuntimeError(message + " Set a long random value in .env before running in production.")
        logger.warning("SECURITY WARNING: %s", message)

    if check_encryption_key():
        logger.info("Uploaded files are encrypted at rest.")
    else:
        logger.warning("SECURITY NOTICE: FILE_ENCRYPTION_KEY is not set, so uploaded files are stored unencrypted.")

    if production and settings.cors_origins.strip() == "*":
        logger.warning("SECURITY NOTICE: CORS_ORIGINS is '*'. Restrict it to your real domain in production.")


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
    Base.metadata.create_all(bind=engine)     # PostgreSQL tables (including the new security tables)
    _apply_light_migrations()                 # newer columns on older tables
    _check_security_config()
    vector_store.ensure_collection()          # Qdrant collection + payload indexes
    threading.Thread(target=_warm_up_models, daemon=True).start()
    logger.info("Startup complete.")


@app.get("/health")
def health_check():
    return {"status": "ok", "vector_db": "ok" if vector_store.is_healthy() else "unreachable"}


app.include_router(auth.router, prefix="/api/v1")
app.include_router(documents.router, prefix="/api/v1")
app.include_router(chat.router, prefix="/api/v1")
app.include_router(security.router, prefix="/api/v1")
