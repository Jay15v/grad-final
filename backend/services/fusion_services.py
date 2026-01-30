from services.model_services import bert_predict
from services.semantic_services import semantic_risk

# Decision thresholds
BLOCK_THRESHOLD = 0.60
HESITATE_THRESHOLD = 0.35


def fuse_prompt(prompt: str):
    # --- Run BERT ---
    bert_risk = bert_predict(prompt)

    # --- Run Semantic ---
    semantic_score, semantic_category, semantic_similarity = semantic_risk(prompt)

    # --- Base weighted fusion ---
    final_risk = (0.6 * bert_risk) + (0.4 * semantic_score)

    prompt_lower = prompt.lower()

    # --------------------------------------------------
    # HARD SECURITY VETOES (must never be ALLOW)
    # --------------------------------------------------
    if semantic_category in [
        "direct_injection",
        "roleplay_jailbreak",
        "obfuscation_payload"
    ]:
        final_risk = max(final_risk, 0.85)

    # Obfuscation keyword assist (extra safety)
    if "base64" in prompt_lower or "decode" in prompt_lower:
        final_risk = max(final_risk, 0.8)

    # --------------------------------------------------
    # CONTEXT SUPPRESSION (reduce false positives)
    # --------------------------------------------------

    # Hypothetical / fictional scenarios
    if semantic_category == "virtualization_hypotheticals":
        final_risk *= 0.6

    # Defensive / educational intent
    if any(word in prompt_lower for word in ["prevent", "defend", "mitigate", "protection"]):
        final_risk *= 0.4

    # --------------------------------------------------
    # FINAL DECISION
    # --------------------------------------------------
    if final_risk >= BLOCK_THRESHOLD:
        decision = "BLOCK"
    elif final_risk >= HESITATE_THRESHOLD:
        decision = "HESITATE"
    else:
        decision = "ALLOW"

    # --------------------------------------------------
    # TRIGGERED LAYERS (for explainability)
    # --------------------------------------------------
    triggered_layers = []

    if bert_risk >= HESITATE_THRESHOLD:
        triggered_layers.append("BERT Classifier")

    if semantic_category:
        triggered_layers.append("Semantic Reasoning")

    triggered_layers.append("Risk Fusion")

    return {
        "decision": decision,
        "bert_risk": round(bert_risk, 3),
        "semantic_risk": round(semantic_score, 3),
        "semantic_similarity": round(semantic_similarity, 3),
        "semantic_category": semantic_category,
        "final_risk": round(final_risk, 3),
        "triggered_layers": triggered_layers
    }
