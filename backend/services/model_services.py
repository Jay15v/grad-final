import os
import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_DIR = os.path.join(BASE_DIR, "models", "bert_prompt_guard")

print("Loading model from:", MODEL_DIR)

if not os.path.exists(MODEL_DIR):
    raise FileNotFoundError(f"Model directory not found: {MODEL_DIR}")

print("🔄 Loading tokenizer...")
tokenizer = AutoTokenizer.from_pretrained(
    MODEL_DIR,
    local_files_only=True
)

print("🔄 Loading model...")
model = AutoModelForSequenceClassification.from_pretrained(
    MODEL_DIR,
    local_files_only=True
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
