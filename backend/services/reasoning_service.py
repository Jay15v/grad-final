from services.llm_service import call_phi3
import re


def generate_reasoning_from_steps(steps: list, original_prompt: str) -> list:
    """
    Uses Phi-3 to generate grounded, structured reasoning per step.

    Each step is explicitly anchored to the original user question
    to prevent hallucination or topic drift.

    Output format:
    [
      {
        "step_id": 1,
        "reasoning": "Explanation text..."
      }
    ]
    """

    reasoning_results = []

    for step in steps:
        step_id = step["id"]
        step_text = step["text"]

        # 🔒 CRITICAL: Context-anchored prompt
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
"""

        explanation = call_phi3(prompt)

        reasoning_results.append({
            "step_id": step_id,
            "reasoning": explanation.strip()
        })

    return reasoning_results
def normalize_claim_for_retrieval(claim: str) -> str:
    claim = claim.strip()

    # Encourage explicit physical phrasing
    replacements = {
        "due to": "because",
        "appears": "appears",
        "by air molecules": "by molecules in the atmosphere",
    }

    for k, v in replacements.items():
        claim = claim.replace(k, v)

    return claim


def generate_claims_from_reasoning(reasoning: list) -> list:
    """
    Extracts atomic, verifiable claims from reasoning output.
    Each claim is grounded in a specific reasoning step.
    RAG-ready.
    """

    claims = []

    for item in reasoning:
        step_id = item["step_id"]
        text = item["reasoning"]

        # Split into atomic factual sentences
        sentences = re.split(r"\.|\n", text)

        for sentence in sentences:
            sentence = sentence.strip()
            if len(sentence) < 12:
                continue

            claims.append({
    "claim": normalize_claim_for_retrieval(sentence),
    "source_step_id": step_id
})


    return claims
