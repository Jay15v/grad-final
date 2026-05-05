import re
import requests

_OLLAMA_URL = "http://localhost:11434/api/generate"


def _call_phi3_long(prompt: str) -> str:
    """Single phi3 call for batched reasoning. 300 tokens ≈ 3 steps × 2 sentences."""
    try:
        resp = requests.post(
            _OLLAMA_URL,
            json={
                "model": "phi3",
                "prompt": prompt,
                "stream": False,
                "options": {"temperature": 0.0, "top_p": 0.9, "num_predict": 300},
            },
            timeout=120,
        )
        resp.raise_for_status()
        return resp.json().get("response", "")
    except Exception as e:
        print(f"⚠️ Phi-3 batch error: {e}")
        return ""


def generate_reasoning_from_steps(steps: list, original_prompt: str) -> list:
    if not steps:
        return []

    steps = steps[:3]  # 3 steps × ~2 sentences ≈ 250 tokens, well within limit

    numbered = "\n".join(
        f"{s.get('id', i + 1)}. {s.get('text', '')}"
        for i, s in enumerate(steps)
    )

    prompt = (
        f'You are a scientific reasoning assistant.\n\n'
        f'Original question: "{original_prompt}"\n\n'
        f'For each numbered subtask below write exactly 2 sentences. '
        f'Start each answer with its number followed by a period.\n\n'
        f'{numbered}'
    )

    raw = _call_phi3_long(prompt)

    results = []
    for step in steps:
        sid = step.get("id", -1)
        pattern = rf"(?:^|\n)\s*{sid}\.\s*(.*?)(?=\n\s*\d+\.|\Z)"
        match = re.search(pattern, raw, re.DOTALL)
        text = match.group(1).strip() if match else ""
        results.append({"step_id": sid, "reasoning": text})

    return results


def normalize_claim_for_retrieval(claim: str) -> str:
    claim = claim.strip()

    replacements = {
        "due to": "because",
        "appears": "appears",
        "by air molecules": "by molecules in the atmosphere",
    }

    for k, v in replacements.items():
        claim = claim.replace(k, v)

    return claim


def generate_claims_from_reasoning(reasoning) -> list:
    """
    Extracts atomic, verifiable factual claims from reasoning output.

    Supports reasoning as list or dict.

    Filters out:
    - meta labels ("Original question:", "Current subtask:", "Rules:")
    - instruction lines (starting with '-' or containing 'do not', 'avoid', etc.)
    - quoted-only lines
    - trailing ':' headers
    - too-short fragments

    Also deduplicates claims per step.
    """

    def is_valid_claim(text: str) -> bool:
        t = (text or "").strip()
        if len(t) < 20:
            return False

        # bullet-like instructions
        if t.startswith("-"):
            return False

        # quoted-only line
        if (t.startswith('"') and t.endswith('"')) or (t.startswith("'") and t.endswith("'")):
            return False

        lt = t.lower()

        # meta / prompt-leak markers
        banned_substrings = [
            "original question",
            "current subtask",
            "rules:",
            "answer only",
            "do not",
            "refrain from",
            "avoid",
            "must be",
            "your answer must",
        ]
        if any(b in lt for b in banned_substrings):
            return False

        # headers like "Something:"
        if lt.endswith(":"):
            return False

        return True

    def clean_text_artifacts(text: str) -> str:
        text = re.sub(r"([a-zA-Z])'s([a-zA-Z])", r"\1's \2", text)
        text = re.sub(r"\b([a-z]{4,})([A-Z][a-z]+)\b", r"\1 \2", text)
        text = re.sub(r"[^\w\s\-\.,;:']", " ", text)
        text = re.sub(r"\s+", " ", text).strip()
        return text


    # Normalize reasoning into list of items: [{"step_id":..., "reasoning":...}, ...]
    items = []

    if isinstance(reasoning, list):
        items = reasoning

    elif isinstance(reasoning, dict):
        # Case 1: {"reasoning": [...]} or {"steps": [...]}
        if isinstance(reasoning.get("reasoning"), list):
            items = reasoning["reasoning"]
        elif isinstance(reasoning.get("steps"), list):
            items = reasoning["steps"]
        else:
            # Case 2: { "1": "...", "2": "..." } mapping
            for k, v in reasoning.items():
                try:
                    step_id = int(k)
                except Exception:
                    continue
                if isinstance(v, str):
                    items.append({"step_id": step_id, "reasoning": v})

    claims = []
    seen = set()  # dedupe

    for item in items:
        step_id = item.get("step_id", -1)
        text = (item.get("reasoning") or "").strip()

        # If the LLM returned nothing for this step, skip it
        if len(text) < 20:
            continue

        # Split into candidate sentences/fragments
        sentences = re.split(r"\.|\n", text)

        for sentence in sentences:
            sentence = (sentence or "").strip()
            if not is_valid_claim(sentence):
                continue

            normalized = normalize_claim_for_retrieval(sentence)
            dedupe_key = (step_id, normalized.lower())
            if dedupe_key in seen:
                continue
            seen.add(dedupe_key)
            sentence = clean_text_artifacts(sentence)
            claims.append({
                "claim": normalized,
                "source_step_id": step_id
            })

    return claims
