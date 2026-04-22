# services/semantic_services.py

from sentence_transformers import SentenceTransformer, util
import json
import os

print("🔄 Loading SBERT...")
sbert = SentenceTransformer("all-MiniLM-L6-v2")
sbert.eval()

BASE_DIR = os.path.dirname(__file__)
DB_PATH = os.path.join(BASE_DIR, "semantic_db.json")

print("🔄 Loading semantic DB...")
with open(DB_PATH, "r") as f:
    SEMANTIC_DB = json.load(f)

print("🔄 Encoding semantic patterns...")
semantic_embeddings = {
    cat: sbert.encode(examples, normalize_embeddings=True)
    for cat, examples in SEMANTIC_DB.items()
}

print("✅ Semantic service ready")


def semantic_risk(prompt: str, threshold: float = 0.7):
    """
    Returns semantic context ONLY.
    No risk scoring here.
    """
    prompt_emb = sbert.encode(prompt, normalize_embeddings=True)

    best_score = 0.0
    best_category = None

    for category, emb in semantic_embeddings.items():
        score = util.cos_sim(prompt_emb, emb).max().item()
        if score > best_score:
            best_score = score
            best_category = category

    print(f"[SEMANTIC] best_category={best_category}, best_score={best_score:.4f}, threshold={threshold}", flush=True)

    # Weak similarity → ignore semantics completely
    if best_score < threshold:
        return None, best_score

    return best_category, best_score
