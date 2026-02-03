import os
import re
import hashlib
import requests
from urllib.parse import urlparse
from bs4 import BeautifulSoup

import faiss
import numpy as np
from sentence_transformers import SentenceTransformer

from bs4 import BeautifulSoup

# --------------------------------------------------
# Config
# --------------------------------------------------
GOOGLE_CSE_API_KEY = "AIzaSyD40Lm_WNKsja02uTKF3vljr1zavqBivOs"
GOOGLE_CSE_ID = "a28ee9c98599245b9"

if not GOOGLE_CSE_API_KEY or not GOOGLE_CSE_ID:
    raise RuntimeError("Missing GOOGLE_CSE_API_KEY or GOOGLE_CSE_ID")


# --------------------------------------------------
# Embedder + FAISS
# --------------------------------------------------
embedder = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")


class LocalFaissStore:
    def __init__(self):
        self.dim = embedder.get_sentence_embedding_dimension()
        self.index = faiss.IndexFlatIP(self.dim)
        self.docs = []
        self._id_set = set()

    def _embed(self, texts):
        vecs = embedder.encode(texts, convert_to_numpy=True).astype("float32")
        faiss.normalize_L2(vecs)
        return vecs

    def add_many(self, docs):
        new_docs = []
        for d in docs:
            if d["id"] in self._id_set:
                continue
            self._id_set.add(d["id"])
            new_docs.append(d)

        if not new_docs:
            return 0

        vecs = self._embed([d["text"] for d in new_docs])
        self.index.add(vecs)
        self.docs.extend(new_docs)
        return len(new_docs)

    def search(self, query, k=5):
        if self.index.ntotal == 0:
            return []

        qv = self._embed([query])
        sims, idxs = self.index.search(qv, k)

        results = []
        for score, idx in zip(sims[0], idxs[0]):
            if idx == -1:
                continue
            results.append({
                **self.docs[idx],
                "similarity": float(score)
            })

        return results


store = LocalFaissStore()


# --------------------------------------------------
# Google Search + Fetch
# --------------------------------------------------
def google_cse_search(query, num=5):
    url = "https://www.googleapis.com/customsearch/v1"
    params = {
        "key": GOOGLE_CSE_API_KEY,
        "cx": GOOGLE_CSE_ID,
        "q": query,
        "num": num,
        "safe": "active",
    }
    r = requests.get(url, params=params, timeout=20)
    r.raise_for_status()
    return r.json().get("items", []) or []


def fetch_page_text(url, max_chars=12000):
    headers = {"User-Agent": "Mozilla/5.0 (RAG-Verifier)"}
    r = requests.get(url, headers=headers, timeout=20)
    r.raise_for_status()

    soup = BeautifulSoup(r.text, "lxml")
    for tag in soup(["script", "style", "noscript", "header", "footer", "nav", "aside"]):
        tag.decompose()

    text = soup.get_text(separator=" ")
    text = " ".join(text.split())
    return text[:max_chars]


def chunk_text(text, chunk_size=220, overlap=40):
    words = text.split()
    chunks = []
    i = 0
    while i < len(words):
        chunk = words[i:i + chunk_size]
        chunks.append(" ".join(chunk))
        i += max(1, chunk_size - overlap)
    return chunks


def stable_id(*parts):
    s = "||".join(parts)
    return hashlib.sha1(s.encode("utf-8")).hexdigest()[:16]


# --------------------------------------------------
# Ingestion + Retrieval
# --------------------------------------------------
def ingest_web_evidence_for_claim(claim, num_results=5, chunks_per_page=6):
    results = google_cse_search(claim, num=num_results)
    docs = []

    for r in results:
        url = r.get("link")
        title = r.get("title", "")
        domain = r.get("displayLink") or urlparse(url).netloc

        try:
            page_text = fetch_page_text(url)
        except Exception:
            continue

        chunks = chunk_text(page_text)[:chunks_per_page]
        for i, ch in enumerate(chunks):
            doc_id = stable_id(url, str(i), ch[:80])
            docs.append({
                "id": f"web_{doc_id}",
                "text": ch,
                "source": domain,
                "url": url,
                "title": title,
            })

    added = store.add_many(docs)
    return {"search_results": results, "added_chunks": added}


# --------------------------------------------------
# Verification
# --------------------------------------------------
def verify_claims_with_rag(claims, k=5):
    results = []

    for c in claims:
        claim_text = c["claim"]
        step_id = c["source_step_id"]

        meta = ingest_web_evidence_for_claim(claim_text)
        evidence = store.search(claim_text, k=k)

        verdict = "NO_EVIDENCE"
        if evidence:
            if evidence[0]["similarity"] >= 0.35:
                verdict = "SUPPORTED_WEAK"
            else:
                verdict = "WEAK"

        results.append({
            "claim": claim_text,
            "source_step_id": step_id,
            "verdict": verdict,
            "best_evidence": evidence[0] if evidence else None,
            "top_evidence": evidence,
            "web_ingest_meta": meta,
        })

    return results
