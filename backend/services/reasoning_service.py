from services.llm_service import call_phi3
import re


def generate_reasoning_from_steps(steps: list, original_prompt: str) -> list:
    """
    Uses Phi-3 to generate grounded, structured reasoning per step.

    Output format:
    [
      {"step_id": 1, "reasoning": "Explanation text..."},
      ...
    ]

    This implementation is resilient:
    - Never throws if the LLM call fails
    - Always returns a list (even if some steps fail)
    """

    reasoning_results = []

    for step in steps:
        step_id = step.get("id", -1)
        step_text = step.get("text", "")

        prompt = f"""
You are an expert scientific reasoning assistant.

Original question:
"{original_prompt}"

Current subtask:
"{step_text}"

Rules:
- Answer ONLY in the context of the original question
- Do NOT introduce unrelated phenomena
- Do NOT generalize beyond the topic
- Do NOT restate the instruction
- Be scientifically accurate
- Write 2–4 clear sentences
""".strip()

        explanation = ""
        try:
            resp = call_phi3(prompt)

            # Normalize bad returns safely
            if resp is None:
                resp = ""
            if not isinstance(resp, str):
                resp = str(resp)

            explanation = resp.strip()

        except Exception as e:
            # Keep pipeline alive even if Phi-3 fails
            print(f"[warn] Phi-3 error at step {step_id}: {e}")
            explanation = ""

        reasoning_results.append({
            "step_id": step_id,
            "reasoning": explanation
        })

    return reasoning_results


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
    # Fix merged possessives like "Earth'seloft"
         text = re.sub(r"([a-zA-Z])'s([a-zA-Z])", r"\1's \2", text)

    # Remove weird token concatenations (e.g., sunrdiscovery)
         text = re.sub(r"\b([a-z]{4,})([A-Z][a-z]+)\b", r"\1 \2", text)

    # Remove repeated non-word characters
         text = re.sub(r"[^\w\s\-\.,;:']", " ", text)

    # Normalize spacing
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
