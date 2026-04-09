import os
import re
import hashlib
from urllib.parse import urlparse

import requests
from bs4 import BeautifulSoup

import faiss
import numpy as np
from sentence_transformers import SentenceTransformer


# ==================================================
# 0) ENV (DO NOT hardcode keys in production)
# ==================================================
GOOGLE_CSE_API_KEY = os.getenv("GOOGLE_CSE_API_KEY", "").strip()
GOOGLE_CSE_ID = os.getenv("GOOGLE_CSE_ID", "").strip()

RAG_ENABLED = bool(GOOGLE_CSE_API_KEY and GOOGLE_CSE_ID)


# ==================================================
# 1) Embedder + FAISS
# ==================================================
embedder = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")


class LocalFaissStore:
    def __init__(self, dim: int):
        self.dim = dim
        self.index = faiss.IndexFlatIP(dim)  # cosine after normalization
        self.docs = []
        self._id_set = set()

    def _embed(self, texts):
        embs = embedder.encode(texts, convert_to_numpy=True).astype("float32")
        faiss.normalize_L2(embs)
        return embs

    def add_many(self, docs):
        new_docs = []
        for d in docs:
            if d["id"] in self._id_set:
                continue
            self._id_set.add(d["id"])
            new_docs.append(d)

        if not new_docs:
            return 0

        embs = self._embed([d["text"] for d in new_docs])
        self.index.add(embs)
        self.docs.extend(new_docs)
        return len(new_docs)

    def search(self, query: str, k: int = 5):
        if self.index.ntotal == 0:
            return []

        qv = self._embed([query])
        sims, idxs = self.index.search(qv, k)

        out = []
        for score, idx in zip(sims[0].tolist(), idxs[0].tolist()):
            if idx == -1:
                continue
            d = self.docs[idx]
            out.append({**d, "similarity": float(score)})
        return out


store = LocalFaissStore(dim=embedder.get_sentence_embedding_dimension())

# Prevent re-ingesting the same claim repeatedly (simple cache)
_ingest_cache = set()


# ==================================================
# 2) Google Search + Fetch
# ==================================================
def google_cse_search(query: str, num: int = 5):
    if not RAG_ENABLED:
        return []

    url = "https://www.googleapis.com/customsearch/v1"
    params = {
        "key": GOOGLE_CSE_API_KEY,
        "cx": GOOGLE_CSE_ID,
        "q": query[:128],     # important: avoid super long queries
        "num": num,
        "safe": "active",
    }

    r = requests.get(url, params=params, timeout=20)
    if r.status_code == 429:
        return []  # rate limited
    r.raise_for_status()

    items = (r.json().get("items") or [])
    out = []
    for it in items:
        out.append({
            "title": it.get("title", ""),
            "link": it.get("link", ""),
            "snippet": it.get("snippet", ""),
            "displayLink": it.get("displayLink", ""),
        })
    return out


def fetch_page_text(url: str, max_chars: int = 12000) -> str:
    headers = {"User-Agent": "Mozilla/5.0 (RAG-Verifier)"}
    r = requests.get(url, headers=headers, timeout=20)
    r.raise_for_status()

    soup = BeautifulSoup(r.text, "lxml")
    for tag in soup(["script", "style", "noscript", "header", "footer", "nav", "aside"]):
        tag.decompose()

    text = soup.get_text(separator=" ")
    text = " ".join(text.split())
    return text[:max_chars]


def chunk_text(text: str, chunk_size: int = 220, overlap: int = 40):
    words = text.split()
    if not words:
        return []
    chunks = []
    i = 0
    while i < len(words):
        chunk = words[i:i + chunk_size]
        chunks.append(" ".join(chunk))
        i += max(1, chunk_size - overlap)
    return chunks


def stable_id(*parts):
    s = "||".join([p or "" for p in parts])
    return hashlib.sha1(s.encode("utf-8")).hexdigest()[:16]


# ==================================================
# 3) Ingest evidence for ONE claim
# ==================================================
def ingest_web_evidence_for_claim(claim: str, num_results: int = 5, chunks_per_page: int = 6):
    if not RAG_ENABLED:
        return {"search_results": [], "added_chunks": 0, "rag_enabled": False}

    cache_key = stable_id(claim)
    if cache_key in _ingest_cache:
        return {"search_results": [], "added_chunks": 0, "rag_enabled": True, "cached": True}

    _ingest_cache.add(cache_key)

    results = google_cse_search(claim, num=num_results)
    new_docs = []

    for r in results:
        url = r.get("link")
        if not url:
            continue

        title = r.get("title", "")
        domain = r.get("displayLink", "") or urlparse(url).netloc

        try:
            page_text = fetch_page_text(url)
        except Exception:
            continue

        chunks = chunk_text(page_text)[:chunks_per_page]
        for ci, ch in enumerate(chunks):
            doc_id = stable_id(url, str(ci), ch[:80])
            new_docs.append({
                "id": f"web_{doc_id}",
                "text": ch,
                "source": domain,
                "url": url,
                "title": title,
            })

    added = store.add_many(new_docs)
    return {"search_results": results, "added_chunks": added, "rag_enabled": True}


# ==================================================
# 4) Similarity + Coverage scoring (your logic)
# ==================================================
STOPWORDS = set("""
a an the and or but if then else this that these those is are was were be been being
of to in for on with as by at from into about over under between within without
it its their them they we you your our i he she his her
""".split())


def normalize_text(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[^a-z0-9\s\-]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def extract_keywords(s: str):
    toks = [t for t in normalize_text(s).split() if t not in STOPWORDS and len(t) > 2]
    return toks


def coverage_score(claim: str, evidence: str) -> float:
    ck = set(extract_keywords(claim))
    if not ck:
        return 0.0
    ek = set(extract_keywords(evidence))
    return len(ck & ek) / len(ck)


def compare_claim_to_candidates(
    claim: str,
    candidates: list,
    sim_threshold: float = 0.30,
    cov_threshold: float = 0.15
):
    filtered = [c for c in candidates if c.get("similarity", 0.0) >= sim_threshold]
    if not filtered:
        return {"verdict": "NO_EVIDENCE", "best": None, "candidates": []}

    for c in filtered:
        c["coverage"] = coverage_score(claim, c["text"])

    filtered.sort(key=lambda x: (x["similarity"], x["coverage"]), reverse=True)
    seen_urls = set()
    unique_candidates = []

    for c in filtered:
       url = c.get("url")
       if url in seen_urls:
          continue
       seen_urls.add(url)
       unique_candidates.append(c)

    filtered = unique_candidates
    best = filtered[0]

    best.setdefault("coverage", coverage_score(claim, best["text"]))

    if best["coverage"] >= cov_threshold:
        return {"verdict": "SUPPORTED_WEAK", "best": best, "candidates": filtered}

    return {"verdict": "WEAK", "best": best, "candidates": filtered}
def compute_hit_miss_stats(results: list) -> dict:
    """
    Role-2 retrieval evaluation:
    - Hit: verdict == SUPPORTED_WEAK (at least one chunk passed similarity + coverage threshold)
    - Miss: otherwise
    """
    total = len(results)
    hits = sum(1 for r in results if r.get("verdict") == "SUPPORTED_WEAK")
    misses = total - hits
    hit_rate = (hits / total) if total else 0.0

    return {
        "total_steps": total,
        "hits": hits,
        "misses": misses,
        "hit_rate": hit_rate
    }



# ==================================================
# 5) MAIN function you call from fusion_services.py
# ==================================================
def verify_claims_with_rag_google(claims, k=5, refresh_web=True):
    """
    claims format expected:
    [
      {"claim": "...", "source_step_id": 1},
      ...
    ]
    """
    results = []

    # We fetch more than k so threshold filtering won't shrink results too much
    oversample_k = max(20, k * 4)  # e.g., k=5 -> 20

    for c in claims:
        claim_text = c["claim"]
        step_id = c.get("source_step_id", -1)

        meta = {"search_results": [], "added_chunks": 0, "rag_enabled": RAG_ENABLED}

        # 1) optionally ingest web evidence
        if refresh_web:
            meta = ingest_web_evidence_for_claim(claim_text, num_results=5, chunks_per_page=6)

        # 2) retrieve MORE candidates than k
        raw_candidates = store.search(claim_text, k=oversample_k)

        # 3) score & verdict (filters + ranks)
        comp = compare_claim_to_candidates(claim_text, raw_candidates)

        # 4) keep only top-k for UI
        topk = (comp["candidates"] or [])[:k]

        results.append({
            "claim": claim_text,
            "source_step_id": step_id,
            "verdict": comp["verdict"],
            "is_hit": comp["verdict"] == "SUPPORTED_WEAK",
            "best_evidence": comp["best"],
            "top_evidence": topk,
            "web_ingest_meta": meta,
        })

    rag_eval = compute_hit_miss_stats(results)
    return {"results": results, "rag_eval": rag_eval}
