import os
import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_DIR = os.path.join(BASE_DIR, "models", "bert_prompt_guard")

# Public HuggingFace fallback — binary classifier (0=safe, 1=injection)
_HF_FALLBACK = "fmops/distilbert-prompt-injection"

_MODEL_FILES = [
    "pytorch_model.bin",
    "model.safetensors",
    "tf_model.h5",
    "model.ckpt.index",
    "flax_model.msgpack",
]

tokenizer = None
model = None
_model_unavailable = False


def _has_model_files(directory: str) -> bool:
    if not os.path.isdir(directory):
        return False
    return any(f in os.listdir(directory) for f in _MODEL_FILES)


os.makedirs(MODEL_DIR, exist_ok=True)

if _has_model_files(MODEL_DIR):
    print("Loading tokenizer from local cache...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR, local_files_only=True)
    print("Loading model from local cache...")
    model = AutoModelForSequenceClassification.from_pretrained(
        MODEL_DIR, local_files_only=True
    ).to(DEVICE)
    model.eval()
    print("BERT model ready")
else:
    try:
        print(f"[download] Local model missing -- downloading {_HF_FALLBACK} from HuggingFace...")
        tokenizer = AutoTokenizer.from_pretrained(_HF_FALLBACK)
        model = AutoModelForSequenceClassification.from_pretrained(_HF_FALLBACK)
        print(f"[save] Saving to {MODEL_DIR} for future restarts...")
        tokenizer.save_pretrained(MODEL_DIR)
        model.save_pretrained(MODEL_DIR)
        model = model.to(DEVICE)
        model.eval()
        print("BERT model ready")
    except Exception as e:
        print(f"[warn] Could not load BERT model: {e}")
        print("[warn] bert_predict will return 0.5 (neutral) until model is available.")
        _model_unavailable = True


def bert_predict(prompt: str) -> float:
    """Returns probability that the prompt is unsafe (0.0–1.0)."""
    if _model_unavailable or model is None or tokenizer is None:
        return 0.5  # neutral fallback

    enc = tokenizer(
        prompt,
        return_tensors="pt",
        truncation=True,
        padding=True,
        max_length=256,
    ).to(DEVICE)

    with torch.no_grad():
        outputs = model(**enc)
        probs = torch.softmax(outputs.logits, dim=1)

    return probs[0, 1].item()
