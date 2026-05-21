import os
import traceback

from services.model_services import bert_predict
from services.semantic_services import semantic_risk
from services.rag_service import verify_claims_with_rag_google
from services.verification_service import verify_rag_output
from services.decomposition_service import decompose_prompt
from services.reasoning_service import (
    generate_reasoning_from_steps,
    generate_claims_from_reasoning
)

RAG_ENABLED = bool(os.getenv("GOOGLE_CSE_API_KEY") and os.getenv("GOOGLE_CSE_ID"))

BLOCK_THRESHOLD = 0.60
HESITATE_THRESHOLD = 0.35


def fuse_prompt(prompt: str):

    # --------------------------------------------------
    # 1️⃣ Base risk from BERT
    # --------------------------------------------------
    bert_risk = bert_predict(prompt)
    final_risk = bert_risk

    # --------------------------------------------------
    # 2️⃣ Semantic domain detection
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
    # 5️⃣ Base response
    # --------------------------------------------------
    response = {
        "status": decision,
        "decision_meta": {
            "bert_risk": round(bert_risk, 3),
            "semantic_domain": semantic_domain,
            "semantic_similarity": round(semantic_similarity, 3),
            "final_risk": round(final_risk, 3),
        }
    }

    # --------------------------------------------------
    # 6️⃣ Structured reasoning ONLY if ALLOW
    # --------------------------------------------------
    if decision == "ALLOW":

        decomposition = {"steps": [], "constraints": {}, "quality": {"score": 0.0}}
        reasoning = []   # ✅ must be list, not {}
        claims = []

        try:
            decomposition = decompose_prompt(prompt)
            steps = decomposition.get("steps", [])

            reasoning = generate_reasoning_from_steps(
                steps=steps,
                original_prompt=prompt
            )

            # Debug (helps you confirm)
            print("DEBUG: steps =", len(steps))
            print("DEBUG: reasoning items =", len(reasoning))
            empty_reasonings = sum(1 for x in reasoning if not (x.get("reasoning") or "").strip())
            print("DEBUG: empty reasoning items =", empty_reasonings)

            claims = generate_claims_from_reasoning(reasoning) or []
            print("DEBUG: claims =", len(claims))

        except Exception as e:
            print("[warn] Decomposition/Reasoning error:", str(e))
            traceback.print_exc()

        rag_results = {
            "results": [],
            "rag_eval": {"total_steps": 0, "hits": 0, "misses": 0, "hit_rate": 0.0}
        }
        verification_results = {
            "role3_results": [],
            "final_control": {
                "final_decision": "ALLOWED",
                "counts": {
                    "supported": 0,
                    "uncertain": 0,
                    "unsupported": 0
                }
            }
        }

        try:
            if claims and RAG_ENABLED:
                rag_results = verify_claims_with_rag_google(claims, k=5, refresh_web=True) or rag_results
            else:
                if not RAG_ENABLED:
                    print("[warn] RAG_DISABLED: Missing GOOGLE_CSE_API_KEY or GOOGLE_CSE_ID")
                if not claims:
                    print("[warn] NO_CLAIMS: Skipping RAG because claims list is empty")
        except Exception as e:
            print("[warn] RAG error:", str(e))
            traceback.print_exc()

        try:
            if rag_results.get("results"):
                verification_results = verify_rag_output(rag_results) or verification_results
            else:
                print("[warn] NO_RAG_RESULTS: Skipping verification because RAG returned no results")
        except Exception as e:
            print("[warn] Verification error:", str(e))
            traceback.print_exc()

        response["decomposition"] = decomposition
        response["reasoning"] = reasoning
        response["claims"] = claims
        response["rag_verification"] = rag_results
        response["verification"] = verification_results
        response["verified_status"] = verification_results["final_control"]["final_decision"]

    return response

