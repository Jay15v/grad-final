from dotenv import load_dotenv
load_dotenv()

import os
from transformers import AutoTokenizer, AutoModelForSequenceClassification

HF_TOKEN = os.environ.get("HF_TOKEN")
HF_MODEL_REPO = os.environ.get("HF_MODEL_REPO")

print(f"Repo: {HF_MODEL_REPO}")
print(f"Token set: {'yes' if HF_TOKEN and HF_TOKEN != 'your_huggingface_token_here' else 'no (public repo mode)'}")

token = HF_TOKEN if (HF_TOKEN and HF_TOKEN != "your_huggingface_token_here") else None

try:
    print("Downloading tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained(HF_MODEL_REPO, token=token)
    print("Downloading model...")
    model = AutoModelForSequenceClassification.from_pretrained(HF_MODEL_REPO, token=token)
    model.eval()
    print("SUCCESS — model loaded from HuggingFace Hub")
except Exception as e:
    print(f"FAILED: {e}")
