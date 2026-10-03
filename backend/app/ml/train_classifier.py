"""Trains the question-type classifier and saves it to app/ml/artifacts/.

Run once during setup (and again any time you extend training_data.py):

    docker compose exec api python -m app.ml.train_classifier

Pipeline: TF-IDF (word 1-2 grams) -> Logistic Regression, one-vs-rest over
the four classes. This is a genuinely trained model, not a keyword lookup —
it learns which words and short phrases correlate with each intent, so it
generalizes to phrasings it has never seen (e.g. "how does X stack up
against Y" still routes to comparison even without the word "compare").
"""
import os
import joblib
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.model_selection import cross_val_score
from .training_data import get_training_data

ARTIFACT_DIR = os.path.join(os.path.dirname(__file__), "artifacts")
ARTIFACT_PATH = os.path.join(ARTIFACT_DIR, "question_classifier.joblib")


def train() -> None:
    texts, labels = get_training_data()

    pipeline = Pipeline([
        ("tfidf", TfidfVectorizer(ngram_range=(1, 2), min_df=1, lowercase=True, stop_words="english")),
        ("clf", LogisticRegression(max_iter=1000, C=3.0, class_weight="balanced")),
    ])

    scores = cross_val_score(pipeline, texts, labels, cv=5)
    print(f"5-fold cross-validation accuracy: {scores.mean():.2%} (+/- {scores.std():.2%})")

    pipeline.fit(texts, labels)

    os.makedirs(ARTIFACT_DIR, exist_ok=True)
    joblib.dump(pipeline, ARTIFACT_PATH)
    print(f"Saved trained classifier to {ARTIFACT_PATH}")


if __name__ == "__main__":
    train()
