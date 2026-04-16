"""
Consensus Engine: queries three Ollama models concurrently, encodes their
responses with SBERT, and returns a semantic-agreement verdict.
"""

from __future__ import annotations

from sentence_transformers import util

from services.semantic_services import sbert
from services.cross_model_service import query_all_models

# ── Thresholds ────────────────────────────────────────────────────────────────
THRESHOLD_CONSENSUS = 0.65
THRESHOLD_PARTIAL   = 0.45

# ── Verdict labels ────────────────────────────────────────────────────────────
VERDICT_LABELS = {
    "CONSENSUS":    "Consensus",
    "PARTIAL":      "Partially Hallucinating",
    "DISAGREEMENT": "High Risk of Hallucination",
}

# ── Canonical pair names (order-independent) ──────────────────────────────────
_PAIR_NAMES: dict[frozenset, str] = {
    frozenset({"phi3",   "llama3"}):  "phi3_llama3",
    frozenset({"phi3",   "mistral"}): "phi3_mistral",
    frozenset({"llama3", "mistral"}): "llama3_mistral",
}


def _first_sentence(text: str) -> str:
    """
    Extract the first sentence from a response text.
    Splits on the first '.', '!', or '?' found.
    Falls back to the full text if no punctuation found.

    Args:
        text: Full model response string.

    Returns:
        First sentence only, stripped of whitespace.
    """
    import re
    match = re.search(r'[.!?]', text)
    if match:
        return text[:match.end()].strip()
    return text.strip()


def _is_error(text: str) -> bool:
    """
    Return True if *text* looks like an error string produced by query_all_models.

    Detects strings that begin with 'error' (case-insensitive) so the engine
    can skip failed model responses when computing similarity.

    Args:
        text: A model response or error string.

    Returns:
        True when the text is an error message, False otherwise.
    """
    return text.lower().startswith("error")


def _pair_name(m1: str, m2: str) -> str:
    """
    Return the canonical display name for a model pair.

    Falls back to '<m1>_<m2>' if the pair is not in the pre-defined table.

    Args:
        m1: First model name.
        m2: Second model name.

    Returns:
        A string like 'phi3_llama3'.
    """
    return _PAIR_NAMES.get(frozenset({m1, m2}), f"{m1}_{m2}")


def cross_model_validate(prompt: str) -> dict:
    """
    Validate a prompt by comparing semantic agreement across three LLM responses.

    Workflow:
      1. Query all three Ollama models with *prompt* via query_all_models().
      2. Filter out any error responses.
      3. Encode each valid response with SBERT (L2-normalised).
      4. Compute cosine similarity for every unique model pair.
      5. Average the pair scores into avg_agreement.
      6. Map avg_agreement to a verdict using THRESHOLD_CONSENSUS / THRESHOLD_PARTIAL.

    Edge case: if one (or more) model returned an error string it is skipped;
    similarity is computed only over the remaining valid responses.

    Args:
        prompt: The user prompt to send to every model.

    Returns:
        A dict with exactly five keys:
          - verdict       (str)  : "CONSENSUS", "PARTIAL", or "DISAGREEMENT"
          - display_label (str)  : Human-readable verdict string
          - avg_agreement (float): Mean cosine similarity across all valid pairs
          - pairs         (list) : [(pair_name, score), ...] for each unique pair
          - responses     (dict) : Raw {model: response_or_error} from query_all_models
    """
    responses = query_all_models(prompt)
    for model, text in responses.items():
        print(f"DEBUG {model}: {text[:80]}")

    # ── Filter valid responses ────────────────────────────────────────────────
    valid = {
        model: text
        for model, text in responses.items()
        if not _is_error(text)
    }

    # ── Encode valid responses ────────────────────────────────────────────────
    embeddings = {
        model: sbert.encode(text, normalize_embeddings=True)
        for model, text in valid.items()
    }

    # ── Compute pairwise cosine similarities ─────────────────────────────────
    models  = list(embeddings.keys())
    pairs   = []
    scores  = []

    for i in range(len(models)):
        for j in range(i + 1, len(models)):
            m1, m2   = models[i], models[j]
            score    = float(util.cos_sim(embeddings[m1], embeddings[m2]).item())
            pairs.append((_pair_name(m1, m2), score))
            scores.append(score)

    # ── Average agreement ─────────────────────────────────────────────────────
    avg_agreement = float(sum(scores) / len(scores)) if scores else 0.0

    # ── Verdict mapping ───────────────────────────────────────────────────────
    if avg_agreement >= THRESHOLD_CONSENSUS:
        verdict = "CONSENSUS"
    elif avg_agreement >= THRESHOLD_PARTIAL:
        verdict = "PARTIAL"
    else:
        verdict = "DISAGREEMENT"

    return {
        "verdict":       verdict,
        "display_label": VERDICT_LABELS[verdict],
        "avg_agreement": avg_agreement,
        "pairs":         pairs,
        "responses":     responses,
    }
