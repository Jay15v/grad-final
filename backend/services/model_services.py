# services/model_services.py

import os
import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
MODEL_DIR = "models/bert_prompt_guard"

# Check if local model weights exist
_LOCAL_FILES = ["pytorch_model.bin", "model.safetensors", "tf_model.h5"]
_has_local_weights = any(
    os.path.exists(os.path.join(MODEL_DIR, f)) for f in _LOCAL_FILES
)

# Fallback: public BERT-based prompt-injection classifier from HuggingFace
FALLBACK_MODEL = "jackhhao/jailbreak-classifier"

if _has_local_weights:
    print("🔄 Loading tokenizer from local model...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR, local_files_only=True)
    print("🔄 Loading model from local weights...")
    model = AutoModelForSequenceClassification.from_pretrained(
        MODEL_DIR, local_files_only=True
    ).to(DEVICE)
else:
    print(f"⚠️  Local model weights not found. Downloading fallback: {FALLBACK_MODEL}")
    print("   (This only happens once — weights will be cached locally)")
    tokenizer = AutoTokenizer.from_pretrained(FALLBACK_MODEL)
    model = AutoModelForSequenceClassification.from_pretrained(
        FALLBACK_MODEL
    ).to(DEVICE)

model.eval()
print("✅ BERT model ready")


def bert_predict(prompt: str) -> float:
    """
    Returns probability that the prompt is unsafe.
    """
    enc = tokenizer(
        prompt,
        return_tensors="pt",
        truncation=True,
        padding=True,
        max_length=256
    ).to(DEVICE)

    with torch.no_grad():
        outputs = model(**enc)
        probs = torch.softmax(outputs.logits, dim=1)

    return probs[0, 1].item()
