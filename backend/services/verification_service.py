import os
import torch
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModelForSequenceClassification

SUPPORT_T = 0.55
UNCERTAIN_T = 0.40

HF_NLI_MODEL = os.environ.get("HF_NLI_MODEL", "cross-encoder/nli-deberta-base")

device = "cuda" if torch.cuda.is_available() else "cpu"

print(f"[Verification] Loading model from HuggingFace Hub: {HF_NLI_MODEL}")

tokenizer_nli = AutoTokenizer.from_pretrained(HF_NLI_MODEL)
model_nli = AutoModelForSequenceClassification.from_pretrained(HF_NLI_MODEL)
model_nli = model_nli.to(device)
model_nli.eval()

print("[Verification] Model loaded successfully")


def nli_probs(premise: str, hypothesis: str, max_len: int = 256):
    inputs = tokenizer_nli(
        premise,
        hypothesis,
        truncation=True,
        max_length=max_len,
        return_tensors="pt"
    ).to(device)

    with torch.no_grad():
        logits = model_nli(**inputs).logits
        probs = F.softmax(logits, dim=-1).squeeze().cpu().numpy()

    id2label = {int(k): v.lower() for k, v in model_nli.config.id2label.items()}
    out = {id2label[i]: float(probs[i]) for i in range(len(probs))}

    if "neutral" not in out and "unknown" in out:
        out["neutral"] = out["unknown"]

    return out


def role3_label_from_probs(probs):
    ent = probs.get("entailment", 0.0)
    con = probs.get("contradiction", 0.0)

    if ent >= 0.80:
        conf = "HIGH"
    elif ent >= 0.60:
        conf = "MEDIUM"
    else:
        conf = "LOW"

    if ent >= SUPPORT_T and ent > con:
        return "Supported", conf
    elif ent >= UNCERTAIN_T and ent > con:
        return "Uncertain", conf
    else:
        return "Unsupported", conf


def verify_claim_with_evidence(claim, evidence_text):
    probs = nli_probs(evidence_text, claim)
    label, confidence = role3_label_from_probs(probs)

    return {
        "claim": claim,
        "label": label,
        "confidence": confidence,
        "entailment": probs.get("entailment"),
        "contradiction": probs.get("contradiction"),
        "neutral": probs.get("neutral"),
    }


def verify_rag_result_item(item):
    claim = item.get("claim", "")
    step_id = item.get("source_step_id", -1)
    rag_verdict = item.get("verdict", "NO_EVIDENCE")
    best = item.get("best_evidence")

    if not best or not best.get("text"):
        return {
            "claim": claim,
            "source_step_id": step_id,
            "rag_verdict": rag_verdict,
            "role3_label": "Unsupported",
            "confidence": "LOW",
            "entailment": None,
            "contradiction": None,
            "neutral": None,
            "evidence_title": None,
            "evidence_url": None,
            "evidence_source": None,
            "evidence_text": None,
        }

    probs = nli_probs(best["text"], claim)
    label, confidence = role3_label_from_probs(probs)

    return {
        "claim": claim,
        "source_step_id": step_id,
        "rag_verdict": rag_verdict,
        "role3_label": label,
        "confidence": confidence,
        "entailment": probs.get("entailment"),
        "contradiction": probs.get("contradiction"),
        "neutral": probs.get("neutral"),
        "evidence_title": best.get("title"),
        "evidence_url": best.get("url"),
        "evidence_source": best.get("source"),
        "evidence_text": best.get("text"),
    }


def verify_rag_output(rag_output):
    rag_results = rag_output.get("results", [])
    verified_results = [verify_rag_result_item(item) for item in rag_results]

    supported = sum(1 for r in verified_results if r["role3_label"] == "Supported")
    uncertain = sum(1 for r in verified_results if r["role3_label"] == "Uncertain")
    unsupported = sum(1 for r in verified_results if r["role3_label"] == "Unsupported")

    final_decision = "ALLOWED" if unsupported == 0 else "BLOCKED"

    return {
        "role3_results": verified_results,
        "final_control": {
            "final_decision": final_decision,
            "counts": {
                "supported": supported,
                "uncertain": uncertain,
                "unsupported": unsupported,
            }
        }
    }