import os
import json
import time
import logging
import shutil
import threading
from datetime import datetime
from pathlib import Path
import torch
from transformers import (
    AutoTokenizer,
    AutoModelForSequenceClassification,
    TrainingArguments,
    Trainer,
    DataCollatorWithPadding,
)
from datasets import Dataset
from sklearn.metrics import f1_score, classification_report
from sklearn.model_selection import train_test_split

# nn Paths
# nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn
BASE_DIR = Path(__file__).resolve().parent.parent
MODEL_LIVE = BASE_DIR / 'models' / 'bert_finetuned'
MODEL_RETRAINED = BASE_DIR / 'models' / 'bert_retrained'
MODEL_BACKUP = BASE_DIR / 'models' / 'bert_backup'
ORIGINAL_DATA = BASE_DIR / 'data' / 'original_train.json'
RETRAIN_LOG = BASE_DIR / 'logs' / 'retrain_log.json'
(BASE_DIR / 'logs').mkdir(exist_ok=True)

# nn Trigger thresholds
# nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn
MIN_TOTAL_CASES = 100  # total buffer cases required
MIN_HUMAN_VERIFIED = 5  # human-labelled cases required
MIN_DAYS_BETWEEN = 7  # minimum days between retraining runs

# nn Runtime state
# nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn
retrain_state = {
    'last_run_ts': 0.0,
    'last_f1_before': None,
    'last_f1_after': None,
    'status': 'idle',  # idle | running | done | failed
    'message': '',
}
_retrain_lock = threading.Lock()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('P4_Retrain')


def check_trigger_conditions():
    """
    Returns (bool, str) — (should_retrain, reason_message).
    ALL three conditions must be True to allow retraining.
    """
    import sqlite3
    db_path = BASE_DIR / 'adaptive_cases.db'
    if not db_path.exists():
        return False, 'No database found — buffer is empty'

    with sqlite3.connect(str(db_path)) as conn:
        total = conn.execute(
            'SELECT COUNT(*) FROM cases'
        ).fetchone()[0]
        human = conn.execute(
            'SELECT COUNT(*) FROM cases WHERE rlhf_label IS NOT NULL'
        ).fetchone()[0]

    if total < MIN_TOTAL_CASES:
        return False, f'Need {MIN_TOTAL_CASES} total cases, have {total}'

    if human < MIN_HUMAN_VERIFIED:
        return False, f'Need {MIN_HUMAN_VERIFIED} human-verified cases, have {human}'

    days_since = (time.time() - retrain_state['last_run_ts']) / 86400
    if days_since < MIN_DAYS_BETWEEN:
        return False, f'Only {days_since:.1f} days since last run (need {MIN_DAYS_BETWEEN})'

    return True, 'All conditions met — retraining is eligible'


def prepare_training_data():
    """
    Returns (train_dataset, test_dataset, stats_dict).
    stats_dict keys: total, from_buffer, human_verified, provisional, original
    """
    from services.adaptive_store import export_for_training
    buffer_cases = export_for_training()  # calls P3

    human_cases = [c for c in buffer_cases if c['is_human_verified']]
    prov_cases = [c for c in buffer_cases if not c['is_human_verified']]

    prompts = []
    labels = []

    # Provisional cases — weight=1, add once
    for c in prov_cases:
        prompts.append(c['prompt'])
        labels.append(c['training_label'])

    # Human-verified cases — weight=2, duplicate the row
    for c in human_cases:
        for _ in range(2):
            prompts.append(c['prompt'])
            labels.append(c['training_label'])

    # Original training data
    orig_count = 0
    if ORIGINAL_DATA.exists():
        with open(ORIGINAL_DATA) as f:
            orig = json.load(f)
            for item in orig:
                prompts.append(item['text'])
                labels.append(item['label'])
                orig_count += 1

    X_train, X_test, y_train, y_test = train_test_split(
        prompts, labels, test_size=0.2, random_state=42, stratify=labels
    )

    train_ds = Dataset.from_dict({'text': X_train, 'label': y_train})
    test_ds = Dataset.from_dict({'text': X_test, 'label': y_test})

    stats = {
        'total': len(prompts),
        'from_buffer': len(buffer_cases),
        'human_verified': len(human_cases),
        'provisional': len(prov_cases),
        'original': orig_count,
    }

    logger.info(f'Dataset prepared: {stats}')
    return train_ds, test_ds, stats


def evaluate_model(model, tokenizer, test_dataset):
    """
    Returns dict with keys:
    f1_overall — weighted F1 on entire test set
    f1_human_verified — weighted F1 on human-verified cases only
    f1_provisional — weighted F1 on provisional cases only
    attack_recall — recall on attack class (label=1)
    report_str — full classification report string
    """
    model.eval()
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    model.to(device)

    all_preds = []
    all_labels = []

    for i in range(0, len(test_dataset), 32):
        batch = test_dataset.select(
            range(i, min(i + 32, len(test_dataset)))
        )
        enc = tokenizer(
            batch['text'],
            truncation=True,
            padding=True,
            max_length=128,
            return_tensors='pt'
        ).to(device)

        with torch.no_grad():
            logits = model(**enc).logits
            all_preds.extend(torch.argmax(logits, dim=-1).cpu().tolist())
            all_labels.extend(batch['label'])

    f1_overall = f1_score(all_labels, all_preds, average='weighted')
    attack_recall = f1_score(all_labels, all_preds, labels=[1], average='macro')
    report_str = classification_report(
        all_labels, all_preds, target_names=['safe', 'attack']
    )

    # Split by is_human_verified column if present
    if 'is_human_verified' in test_dataset.column_names:
        hv_flag = test_dataset['is_human_verified']
        hv_l = [l for l, f in zip(all_labels, hv_flag) if f]
        hv_p = [p for p, f in zip(all_preds, hv_flag) if f]
        pr_l = [l for l, f in zip(all_labels, hv_flag) if not f]
        pr_p = [p for p, f in zip(all_preds, hv_flag) if not f]
        f1_hv = f1_score(hv_l, hv_p, average='weighted') if hv_l else None
        f1_pr = f1_score(pr_l, pr_p, average='weighted') if pr_l else None
    else:
        f1_hv = f1_pr = None

    return {
        'f1_overall': round(f1_overall, 4),
        'f1_human_verified': round(f1_hv, 4) if f1_hv is not None else 'N/A',
        'f1_provisional': round(f1_pr, 4) if f1_pr is not None else 'N/A',
        'attack_recall': round(attack_recall, 4),
        'report_str': report_str,
    }


def _hot_swap():
    """
    Replace MODEL_LIVE with MODEL_RETRAINED.
    Backup MODEL_LIVE to MODEL_BACKUP first — always keep a rollback copy.
    """
    if MODEL_LIVE.exists():
        if MODEL_BACKUP.exists():
            shutil.rmtree(MODEL_BACKUP)
        shutil.copytree(MODEL_LIVE, MODEL_BACKUP)
        logger.info(f'Backed up live model to {MODEL_BACKUP}')

    if MODEL_LIVE.exists():
        shutil.rmtree(MODEL_LIVE)
    shutil.copytree(MODEL_RETRAINED, MODEL_LIVE)
    logger.info('Hot Model Swap complete — new BERT is now live')


def _print_results(metrics_before, metrics_after, improved):
    """Print the three-column F1 comparison table to terminal."""
    tag = 'IMPROVED' if improved else 'NO CHANGE'
    print('\n' + '=' * 60)
    print(f' BERT RETRAINING RESULTS [{tag}]')
    print('=' * 60)
    print(f" F1 Overall: {metrics_before['f1_overall']:.4f} -> {metrics_after['f1_overall']:.4f}")
    print(f" F1 Human-Verified: {metrics_before['f1_human_verified']} -> {metrics_after['f1_human_verified']}")
    print(f" F1 Provisional: {metrics_before['f1_provisional']} -> {metrics_after['f1_provisional']}")
    print(f" Attack Recall: {metrics_before['attack_recall']:.4f} -> {metrics_after['attack_recall']:.4f}")
    hot_swap_msg = 'YES — new model is live' if improved else 'NO — old model kept'
    print(f" Hot Swap: {hot_swap_msg}")
    print('=' * 60 + '\n')


def _log_result(metrics_before, metrics_after, stats, improved):
    """Append one retraining result entry to retrain_log.json."""
    entry = {
        'timestamp': datetime.utcnow().isoformat(),
        'improved': improved,
        'f1_before': metrics_before['f1_overall'],
        'f1_after': metrics_after['f1_overall'],
        'f1_hv_before': metrics_before['f1_human_verified'],
        'f1_hv_after': metrics_after['f1_human_verified'],
        'f1_prov_before': metrics_before['f1_provisional'],
        'f1_prov_after': metrics_after['f1_provisional'],
        'attack_recall_before': metrics_before['attack_recall'],
        'attack_recall_after': metrics_after['attack_recall'],
        'dataset_stats': stats,
    }

    history = []
    if RETRAIN_LOG.exists():
        with open(RETRAIN_LOG) as f:
            history = json.load(f)
    history.append(entry)
    with open(RETRAIN_LOG, 'w') as f:
        json.dump(history, f, indent=2)
    logger.info(f'Retrain log updated: {RETRAIN_LOG}')


def run_retraining(force=False):
    """
    Full retraining pipeline.
    force=True bypasses trigger condition checks (use for testing only).
    Updates retrain_state in place. Thread-safe via _retrain_lock.
    Never call this directly from a Flask route — always use threading.Thread.
    """
    global retrain_state
    if not _retrain_lock.acquire(blocking=False):
        logger.info('Retraining already in progress — skipping duplicate call')
        return

    try:
        retrain_state['status'] = 'running'
        retrain_state['message'] = 'Starting retraining pipeline...'

        # Step 1 — Check trigger conditions
        if not force:
            ok, msg = check_trigger_conditions()
            if not ok:
                retrain_state['status'] = 'idle'
                retrain_state['message'] = msg
                logger.info(f'Trigger conditions not met: {msg}')
                return

        # Step 2 — Load current live model for before-evaluation
        retrain_state['message'] = 'Loading current model for baseline evaluation...'
        tokenizer = AutoTokenizer.from_pretrained(str(MODEL_LIVE))
        model_old = AutoModelForSequenceClassification.from_pretrained(str(MODEL_LIVE))

        # Step 3 — Prepare training dataset
        retrain_state['message'] = 'Preparing training dataset...'
        train_ds, test_ds, stats = prepare_training_data()

        # Step 4 — Evaluate OLD model (before)
        retrain_state['message'] = 'Evaluating current model (before)...'
        metrics_before = evaluate_model(model_old, tokenizer, test_ds)
        del model_old  # free RAM before loading a second model

        # Step 5 — Tokenize
        retrain_state['message'] = 'Tokenizing dataset...'
        def tokenize_fn(batch):
            return tokenizer(
                batch['text'], truncation=True,
                padding='max_length', max_length=128
            )
        train_tok = train_ds.map(tokenize_fn, batched=True)
        test_tok = test_ds.map(tokenize_fn, batched=True)

        # Step 6 — Fine-tune new model for 3 epochs
        retrain_state['message'] = 'Fine-tuning BERT — 3 epochs...'
        model_new = AutoModelForSequenceClassification.from_pretrained(
            str(MODEL_LIVE), num_labels=2
        )
        training_args = TrainingArguments(
            output_dir=str(MODEL_RETRAINED),
            num_train_epochs=3,
            per_device_train_batch_size=16,
            per_device_eval_batch_size=32,
            evaluation_strategy='epoch',
            save_strategy='epoch',
            load_best_model_at_end=True,
            metric_for_best_model='eval_loss',
            logging_dir=str(BASE_DIR / 'logs'),
            logging_steps=50,
            report_to='none',
        )

        def compute_metrics(eval_pred):
            logits, labels = eval_pred
            preds = logits.argmax(-1)
            return {'f1': f1_score(labels, preds, average='weighted')}

        trainer = Trainer(
            model=model_new,
            args=training_args,
            train_dataset=train_tok,
            eval_dataset=test_tok,
            tokenizer=tokenizer,
            data_collator=DataCollatorWithPadding(tokenizer),
            compute_metrics=compute_metrics,
        )
        trainer.train()
        model_new.save_pretrained(str(MODEL_RETRAINED))
        tokenizer.save_pretrained(str(MODEL_RETRAINED))

        # Step 7 — Evaluate NEW model (after)
        retrain_state['message'] = 'Evaluating new model (after)...'
        metrics_after = evaluate_model(model_new, tokenizer, test_ds)

        # Step 8 — Compare and decide
        f1_before = metrics_before['f1_overall']
        f1_after = metrics_after['f1_overall']
        improved = f1_after > f1_before

        retrain_state['last_f1_before'] = f1_before
        retrain_state['last_f1_after'] = f1_after
        retrain_state['last_run_ts'] = time.time()

        # Step 9 — Hot swap if improved
        if improved:
            _hot_swap()

        # Step 10 — Report
        msg = (
            f'Success — F1 improved {f1_before:.4f} -> {f1_after:.4f}. Model swapped.'
            if improved else
            f'No improvement — F1 {f1_before:.4f} -> {f1_after:.4f}. Old model kept.'
        )
        retrain_state['status'] = 'done'
        retrain_state['message'] = msg

        _print_results(metrics_before, metrics_after, improved)
        _log_result(metrics_before, metrics_after, stats, improved)

    except Exception as e:
        logger.error(f'Retraining failed: {e}', exc_info=True)
        retrain_state['status'] = 'failed'
        retrain_state['message'] = str(e)

    finally:
        _retrain_lock.release()
