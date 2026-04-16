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
    print(f"🔄 Loading BERT model from: {MODEL_DIR}  (retrained local weights)")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR, local_files_only=True)
    model = AutoModelForSequenceClassification.from_pretrained(
        MODEL_DIR, local_files_only=True
    ).to(DEVICE)
    _active_model_name = MODEL_DIR
else:
    print(f"⚠️  Local model weights not found. Loading fallback: {FALLBACK_MODEL}")
    tokenizer = AutoTokenizer.from_pretrained(FALLBACK_MODEL)
    model = AutoModelForSequenceClassification.from_pretrained(
        FALLBACK_MODEL
    ).to(DEVICE)
    _active_model_name = FALLBACK_MODEL

model.eval()
print(f"✅ BERT model ready  →  active model: [{_active_model_name}]  device: [{DEVICE}]")


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
