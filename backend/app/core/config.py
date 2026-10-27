from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # LLM provider: "gemini" | "openai" | "anthropic"
    llm_provider: str = "gemini"
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.5-flash"
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"
    anthropic_api_key: str = ""
    anthropic_model: str = "claude-sonnet-5"

    # PostgreSQL
    database_url: str = "postgresql+psycopg://archive_user:archive_pass@db:5432/archive_db"

    # Qdrant
    qdrant_url: str = "http://qdrant:6333"
    qdrant_api_key: str = ""  # required for Qdrant Cloud, blank for local/Docker Qdrant
    qdrant_collection: str = "document_chunks"

    # Embeddings + chunking
    embedding_model: str = "BAAI/bge-small-en-v1.5"
    vector_dimension: int = 384
    chunk_size: int = 1000
    chunk_overlap: int = 150
    min_relevance: float = 0.30

    # Auth
    jwt_secret_key: str = "dev-secret-change-me"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 1440
    google_client_id: str = ""
    facebook_app_id: str = ""
    facebook_app_secret: str = ""
    # Path to the Firebase service-account JSON you download from
    # Firebase Console (used to verify phone-auth tokens server-side)
    firebase_credentials_path: str = ""

    # Storage / CORS
    upload_dir: str = "/app/storage/uploads"
    cors_origins: str = "*"

    # ── Security ────────────────────────────────────────────────────────
    # "production" makes the server REFUSE to start with a weak JWT secret.
    environment: str = "development"
    # Set false in production to hide the /docs and /openapi.json pages.
    enable_docs: bool = True
    # Only set true when the app sits behind a proxy you trust (Render,
    # Cloud Run, nginx). Otherwise clients could fake their IP address.
    trust_proxy_headers: bool = False
    # Facebook does not guarantee its emails are verified, so by default we
    # never link a Facebook login to an existing account by email.
    trust_facebook_email: bool = False
    # Fernet key. When set, uploaded files are encrypted on disk.
    # Generate: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
    file_encryption_key: str = ""
    max_upload_mb: int = 25
    max_unpacked_mb: int = 300  # zip-bomb guard for .docx files
    # Passages that look like hidden instructions are excluded from answers.
    quarantine_suspicious_chunks: bool = True
    rate_limit_auth_per_minute: int = 10
    rate_limit_chat_per_minute: int = 30
    rate_limit_upload_per_minute: int = 10
    rate_limit_share_per_minute: int = 10


settings = Settings()
