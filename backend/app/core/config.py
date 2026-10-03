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
    database_url: str = "postgresql+psycopg2://archive_user:archive_pass@db:5432/archive_db"

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

    # Storage / CORS
    upload_dir: str = "/app/storage/uploads"
    cors_origins: str = "*"


settings = Settings()
