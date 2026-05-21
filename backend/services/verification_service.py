import os
import shutil
import torch
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModelForSequenceClassification

SUPPORT_T = 0.55
UNCERTAIN_T = 0.40

MODEL_PATH = os.path.join(
    os.path.dirname(os.path.dirname(__file__)),
    "models",
    "deberta_nli_verifier"
)

# Public HuggingFace NLI model (3-class: entailment / neutral / contradiction)
_HF_FALLBACK = "cross-encoder/nli-deberta-v3-small"

_MODEL_FILES = [
    "pytorch_model.bin",
    "model.safetensors",
    "tf_model.h5",
    "model.ckpt.index",
    "flax_model.msgpack",
]

device = "cuda" if torch.cuda.is_available() else "cpu"

tokenizer_nli = None
model_nli = None
_nli_unavailable = False


def _has_model_files(directory: str) -> bool:
    if not os.path.isdir(directory):
        return False
    return any(f in os.listdir(directory) for f in _MODEL_FILES)


os.makedirs(MODEL_PATH, exist_ok=True)

print(f"[Verification] Loading model from: {MODEL_PATH}")

if _has_model_files(MODEL_PATH):
    try:
        tokenizer_nli = AutoTokenizer.from_pretrained(MODEL_PATH, local_files_only=True)
        model_nli = AutoModelForSequenceClassification.from_pretrained(
            MODEL_PATH, local_files_only=True
        ).to(device)
        model_nli.eval()
        print("[Verification] Model loaded from local cache")
    except Exception as e:
        print(f"[Verification] Local files corrupted ({e}) -- clearing and re-downloading...")
        shutil.rmtree(MODEL_PATH)
        os.makedirs(MODEL_PATH, exist_ok=True)

if model_nli is None and not _nli_unavailable:
    try:
        print(f"[Verification] Downloading {_HF_FALLBACK} from HuggingFace...")
        tokenizer_nli = AutoTokenizer.from_pretrained(_HF_FALLBACK)
        model_nli = AutoModelForSequenceClassification.from_pretrained(_HF_FALLBACK)
        print(f"[Verification] Saving to {MODEL_PATH}...")
        tokenizer_nli.save_pretrained(MODEL_PATH)
        model_nli.save_pretrained(MODEL_PATH)
        model_nli = model_nli.to(device)
        model_nli.eval()
        print("[Verification] Model ready")
    except Exception as e:
        print(f"[Verification] Could not load NLI model: {e}")
        print("[Verification] verify_rag_output will return neutral results until model is available.")
        _nli_unavailable = True


def nli_probs(premise: str, hypothesis: str, max_len: int = 256):
    if _nli_unavailable or model_nli is None or tokenizer_nli is None:
        return {"entailment": 0.33, "neutral": 0.34, "contradiction": 0.33}

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
