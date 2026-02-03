from services.model_services import bert_predict
from services.semantic_services import semantic_risk
from services.rag_service import verify_claims_with_rag

# Structured reasoning imports
from services.decomposition_service import decompose_prompt
from services.reasoning_service import (
    generate_reasoning_from_steps,
    generate_claims_from_reasoning
)

# --------------------------------------------------
# Global decision thresholds
# --------------------------------------------------
BLOCK_THRESHOLD = 0.60
HESITATE_THRESHOLD = 0.35


def fuse_prompt(prompt: str):
    """
    Domain-adaptive fusion engine with structured reasoning and RAG-ready claims.

    Pipeline:
    1) BERT → base statistical risk
    2) SBERT → semantic domain (context only)
    3) Domain-aware calibration
    4) Decision (ALLOW / HESITATE / BLOCK)
    5) IF ALLOW:
        - Decomposition
        - Phi-3 reasoning (prompt-grounded)
        - Claim extraction (from reasoning)
        - Optional RAG verification
    """

    # --------------------------------------------------
    # 1️⃣ Base risk from BERT
    # --------------------------------------------------
    bert_risk = bert_predict(prompt)
    final_risk = bert_risk

    # --------------------------------------------------
    # 2️⃣ Semantic domain detection (context only)
    # --------------------------------------------------
    semantic_domain, semantic_similarity = semantic_risk(prompt)

    # --------------------------------------------------
    # 3️⃣ Domain-adaptive calibration
    # --------------------------------------------------
    if semantic_domain == "roleplay_jailbreak":
        final_risk = max(bert_risk * 0.8, 0.35)

    elif semantic_domain == "direct_injection":
        final_risk = max(bert_risk * 1.2, 0.50)

    elif semantic_domain == "obfuscation_payload":
        final_risk = max(bert_risk * 1.3, 0.55)

    elif semantic_domain == "virtualization_hypotheticals":
        final_risk = bert_risk * 0.6

    else:
        final_risk = bert_risk

    # --------------------------------------------------
    # 4️⃣ Final decision
    # --------------------------------------------------
    if final_risk >= BLOCK_THRESHOLD:
        decision = "BLOCK"
    elif final_risk >= HESITATE_THRESHOLD:
        decision = "HESITATE"
    else:
        decision = "ALLOW"

    # --------------------------------------------------
    # 5️⃣ Explainability layers
    # --------------------------------------------------
    triggered_layers = ["BERT Risk Estimation"]

    if semantic_domain:
        triggered_layers.append("Semantic Domain Adaptation")

    triggered_layers.append("Decision Policy")

    # --------------------------------------------------
    # 6️⃣ Base response (ALWAYS returned)
    # --------------------------------------------------
    response = {
        "status": decision,
        "decision_meta": {
            "bert_risk": round(bert_risk, 3),
            "semantic_domain": semantic_domain,
            "semantic_similarity": round(semantic_similarity, 3),
            "final_risk": round(final_risk, 3),
            "triggered_layers": triggered_layers
        }
    }

    # --------------------------------------------------
    # 7️⃣ Structured reasoning (ONLY if ALLOW)
    # --------------------------------------------------
    if decision == "ALLOW":
        # 7.1 Decompose the prompt
        decomposition = decompose_prompt(prompt)
        steps = decomposition.get("steps", [])

        # 7.2 Prompt-grounded Phi-3 reasoning per step
        reasoning = generate_reasoning_from_steps(
            steps=steps,
            original_prompt=prompt
        )

        # 7.3 Claims extracted FROM reasoning (atomic facts)
        claims = generate_claims_from_reasoning(reasoning)

        # 7.4 Optional RAG verification (safe to disable)
        rag_results = verify_claims_with_rag(claims)

        # 7.5 Attach structured outputs
        response["decomposition"] = decomposition
        response["reasoning"] = reasoning
        response["claims"] = claims
        response["rag_verification"] = rag_results

    return response
