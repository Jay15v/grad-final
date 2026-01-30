import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification
from services.semantic_services import semantic_risk
from services.semantic_services import semantic_risk

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
MODEL_DIR = "models/bert_prompt_guard"

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

    return probs[0, 1].item()  # unsafe probability
def analyze_prompt(prompt):
    bert_score = bert_predict(prompt)
    sem_score, sem_category, sem_similarity = semantic_risk(prompt)

    return {
        "bert_risk": bert_score,
        "semantic_risk": sem_score,
        "semantic_similarity": sem_similarity,
        "semantic_category": sem_category
    }
