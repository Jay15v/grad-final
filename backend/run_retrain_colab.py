import os
import sys
import time

# nn Set your project path here nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn
# If running on Colab with Google Drive mounted:
PROJECT_PATH = '/content/drive/MyDrive/grad-final/backend'

# If running locally (not Colab), comment the line above and uncomment below:
# PROJECT_PATH = os.path.dirname(os.path.abspath(__file__))

sys.path.insert(0, PROJECT_PATH)
os.chdir(PROJECT_PATH)

# nn Reset the 7-day timer so retraining is not blocked nnnnnnnnnnnnnnnnnnnnn
from services.retrain_bert import retrain_state, run_retraining

retrain_state['last_run_ts'] = 0

# nn Run retraining directly (force=True bypasses trigger checks entirely) nn
print('Starting BERT retraining...')
print('This will:')
print(' 1. Load models/bert_finetuned/ as the baseline model')
print(' 2. Export cases from adaptive_cases.db via P3')
print(' 3. Apply 2x weighting to human-verified cases')
print(' 4. Fine-tune for 3 epochs')
print(' 5. Compare F1 before vs after')
print(' 6. Hot swap if F1 improved')
print(' 7. Save results to logs/retrain_log.json')
print()

# force=True — bypasses MIN_TOTAL_CASES, MIN_HUMAN_VERIFIED, MIN_DAYS checks
run_retraining(force=True)

print()
print('Final state:')
print(f' status: {retrain_state["status"]}')
print(f' message: {retrain_state["message"]}')
print(f' F1 before: {retrain_state["last_f1_before"]}')
print(f' F1 after: {retrain_state["last_f1_after"]}')
