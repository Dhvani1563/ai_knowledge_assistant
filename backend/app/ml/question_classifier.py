import os
import logging
from functools import lru_cache
import joblib
from .train_classifier import ARTIFACT_PATH, train

logger = logging.getLogger(__name__)

VALID_LABELS = {"factual", "summarization", "comparison", "retrieval"}


@lru_cache(maxsize=1)
def _get_pipeline():
    if not os.path.exists(ARTIFACT_PATH):
        logger.info("No trained classifier found at %s — training one now.", ARTIFACT_PATH)
        train()
    return joblib.load(ARTIFACT_PATH)


def classify_question(question: str) -> tuple[str, float]:
    """Returns (label, confidence). This is the routing step described in
    the product spec: the label decides how `rag_pipeline.py` frames the
    prompt and which chunks it prioritizes, so the app is doing more than
    forwarding text straight to an LLM.
    """
    pipeline = _get_pipeline()
    label = pipeline.predict([question])[0]
    proba = pipeline.predict_proba([question])[0]
    confidence = float(max(proba))
    return label, confidence
