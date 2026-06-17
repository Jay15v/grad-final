from dotenv import load_dotenv
load_dotenv()

import os
from huggingface_hub import HfApi

HF_TOKEN = os.environ.get("HF_TOKEN")
HF_MODEL_REPO = os.environ.get("HF_MODEL_REPO")

if not HF_TOKEN or HF_TOKEN == "your_huggingface_token_here":
    print("ERROR: Set HF_TOKEN in your .env file first.")
    print("Get it from: https://huggingface.co/settings/tokens (Write access)")
    exit(1)

MODEL_DIR = os.path.join(os.path.dirname(__file__), "models", "bert_prompt_guard")

api = HfApi(token=HF_TOKEN)

print(f"Uploading model files to {HF_MODEL_REPO} ...")
api.upload_folder(
    folder_path=MODEL_DIR,
    repo_id=HF_MODEL_REPO,
    repo_type="model",
)

print(f"Done! Model live at: https://huggingface.co/{HF_MODEL_REPO}")
