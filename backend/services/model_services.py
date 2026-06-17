import os
import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification
from huggingface_hub import login

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

HF_TOKEN = os.environ.get("HF_TOKEN")
HF_MODEL_REPO = os.environ.get("HF_MODEL_REPO")  # e.g. "yourname/bert-prompt-guard"

if not HF_MODEL_REPO:
    raise EnvironmentError("HF_MODEL_REPO env var is not set")

if HF_TOKEN and HF_TOKEN != "your_huggingface_token_here":
    login(token=HF_TOKEN, add_to_git_credential=False)

print(f"Loading model from HuggingFace Hub: {HF_MODEL_REPO}")

print("Loading tokenizer...")
tokenizer = AutoTokenizer.from_pretrained(HF_MODEL_REPO)

print("Loading model...")
model = AutoModelForSequenceClassification.from_pretrained(HF_MODEL_REPO).to(DEVICE)
model.eval()
print("BERT model ready")


def bert_predict(prompt: str) -> float:
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
