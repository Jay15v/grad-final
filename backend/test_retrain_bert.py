import os
import sys
import json
import time
import sqlite3
import shutil
import tempfile
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from services.retrain_bert import (
    check_trigger_conditions,
    prepare_training_data,
    _hot_swap,
    _log_result,
    _print_results,
    retrain_state,
    MIN_TOTAL_CASES,
    MIN_HUMAN_VERIFIED,
    MIN_DAYS_BETWEEN,
)
import services.retrain_bert as retrain_module

passed = 0
failed = 0


def check(name, condition, details=''):
    global passed, failed
    if condition:
        print(f'  PASS — {name}')
        passed += 1
    else:
        print(f'  FAIL — {name} {details}')
        failed += 1


def make_seeded_db(tmp_path, total=105, human=6):
    db = Path(tmp_path) / 'adaptive_cases.db'
    conn = sqlite3.connect(str(db))
    conn.execute('''CREATE TABLE cases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prompt TEXT, verdict TEXT, risk_score REAL,
        label INTEGER DEFAULT 1,
        rlhf_label INTEGER, rlhf_pending INTEGER DEFAULT 0,
        created_at REAL, child_id TEXT, parent_id TEXT, prompt_hash TEXT
    )''')
    old = time.time() - (49 * 3600)
    for i in range(total - human):
        conn.execute(
            'INSERT INTO cases VALUES (NULL,?,?,0.9,1,NULL,0,?,NULL,NULL,?)',
            (f'block prompt {i}', 'BLOCK', old, f'bh{i}')
        )
    for i in range(human):
        conn.execute(
            'INSERT INTO cases VALUES (NULL,?,?,0.65,1,1,0,?,NULL,NULL,?)',
            (f'hesitate {i}', 'HESITATE', old, f'hh{i}')
        )
    conn.commit()
    conn.close()
    return db


tmp_dir = tempfile.mkdtemp()

print('=' * 70)
print('AegisMind P4 Retrain Pipeline Test Suite')
print('=' * 70)

# ── TEST GROUP 1: check_trigger_conditions() ─────────────────
print('\n--- TEST GROUP 1: check_trigger_conditions() ---')

# Test 1: Returns False when database does not exist
with patch.object(retrain_module, 'BASE_DIR', Path(tmp_dir) / 'empty'):
    ok, msg = check_trigger_conditions()
    check('Returns False when no database exists', not ok, f'msg={msg}')

# Test 2: Returns False when total cases < MIN_TOTAL_CASES
db_path = make_seeded_db(tmp_dir, total=50, human=6)
with patch.object(retrain_module, 'BASE_DIR', Path(tmp_dir)):
    ok, msg = check_trigger_conditions()
    check('Returns False when total cases below threshold', not ok, f'msg={msg}')
import gc
gc.collect()
import time as time_module
time_module.sleep(0.1)
try:
    os.remove(db_path)
except:
    pass

# Test 3: Returns False when human-verified < MIN_HUMAN_VERIFIED
db_path = make_seeded_db(tmp_dir, total=105, human=2)
with patch.object(retrain_module, 'BASE_DIR', Path(tmp_dir)):
    ok, msg = check_trigger_conditions()
    check('Returns False when human-verified below threshold', not ok, f'msg={msg}')
gc.collect()
time_module.sleep(0.1)
try:
    os.remove(db_path)
except:
    pass

# Test 4: Returns False when not enough days have passed
db_path = make_seeded_db(tmp_dir, total=105, human=6)
original_ts = retrain_state['last_run_ts']
retrain_state['last_run_ts'] = time.time()
with patch.object(retrain_module, 'BASE_DIR', Path(tmp_dir)):
    ok, msg = check_trigger_conditions()
    check('Returns False when not enough days since last run', not ok, f'msg={msg}')
retrain_state['last_run_ts'] = original_ts
gc.collect()
time_module.sleep(0.1)
try:
    os.remove(db_path)
except:
    pass

# Test 5: Returns True when all conditions met
db_path = make_seeded_db(tmp_dir, total=105, human=6)
retrain_state['last_run_ts'] = 0
with patch.object(retrain_module, 'BASE_DIR', Path(tmp_dir)):
    ok, msg = check_trigger_conditions()
    check('Returns True when all conditions are met', ok, f'msg={msg}')
gc.collect()
time_module.sleep(0.1)
try:
    os.remove(db_path)
except:
    pass

# ── TEST GROUP 2: prepare_training_data() ────────────────────
print('\n--- TEST GROUP 2: prepare_training_data() ---')


def make_mock_cases(n_human=3, n_prov=5):
    cases = []
    for i in range(n_human):
        cases.append({
            'case_id': i, 'prompt': f'human prompt {i}',
            'training_label': 1, 'is_human_verified': True, 'weight': 2
        })
    for i in range(n_prov):
        cases.append({
            'case_id': n_human + i, 'prompt': f'prov prompt {i}',
            'training_label': 1, 'is_human_verified': False, 'weight': 1
        })
    return cases


# Test 6: Human-verified rows appear exactly 2x
mock_cases = make_mock_cases(n_human=4, n_prov=4)
with patch('services.adaptive_store.export_for_training', return_value=mock_cases):
    with patch.object(retrain_module, 'ORIGINAL_DATA', Path('/nonexistent')):
        train_ds, test_ds, stats = prepare_training_data()
        check(
            'Human-verified rows duplicated 2x in dataset',
            stats['total'] == 12,
            f'expected 12, got {stats["total"]}'
        )

# Test 7: Provisional rows appear exactly 1x
check(
    'Provisional rows appear exactly 1x',
    stats['provisional'] == 4,
    f'expected provisional=4, got {stats["provisional"]}'
)

# Test 8: Stats dict has all required keys
required_stat_keys = ['total', 'from_buffer', 'human_verified', 'provisional', 'original']
check(
    'Stats dict has all required keys',
    all(k in stats for k in required_stat_keys),
    f'got keys: {list(stats.keys())}'
)

# Test 9: Train/test split is approximately 80/20
total_split = len(train_ds) + len(test_ds)
test_ratio = len(test_ds) / total_split
check(
    'Train/test split is approximately 80/20',
    0.15 <= test_ratio <= 0.35,
    f'test_ratio={test_ratio:.2f}'
)

# ── TEST GROUP 3: _hot_swap() ─────────────────────────────────
print('\n--- TEST GROUP 3: _hot_swap() ---')

fake_live      = Path(tmp_dir) / 'bert_finetuned'
fake_retrained = Path(tmp_dir) / 'bert_retrained'
fake_backup    = Path(tmp_dir) / 'bert_backup'
fake_live.mkdir()
fake_retrained.mkdir()
(fake_live      / 'config.json').write_text('{"model":"old"}')
(fake_retrained / 'config.json').write_text('{"model":"new"}')

with patch.object(retrain_module, 'MODEL_LIVE', fake_live):
    with patch.object(retrain_module, 'MODEL_RETRAINED', fake_retrained):
        with patch.object(retrain_module, 'MODEL_BACKUP', fake_backup):
            _hot_swap()
            live_content   = (fake_live   / 'config.json').read_text()
            backup_content = (fake_backup / 'config.json').read_text()

# Test 10: MODEL_LIVE now contains new model
check(
    'MODEL_LIVE contains new model after swap',
    '"new"' in live_content,
    f'content={live_content}'
)

# Test 11: MODEL_BACKUP contains old model
check(
    'MODEL_BACKUP contains old model after swap',
    '"old"' in backup_content,
    f'content={backup_content}'
)

# ── TEST GROUP 4: _log_result() ───────────────────────────────
print('\n--- TEST GROUP 4: _log_result() ---')

fake_log = Path(tmp_dir) / 'retrain_log.json'
fake_before = {
    'f1_overall': 0.85, 'f1_human_verified': 0.88,
    'f1_provisional': 0.83, 'attack_recall': 0.90, 'report_str': 'test'
}
fake_after = {
    'f1_overall': 0.90, 'f1_human_verified': 0.93,
    'f1_provisional': 0.87, 'attack_recall': 0.94, 'report_str': 'test'
}
fake_stats = {'total': 120, 'human_verified': 8, 'provisional': 97, 'original': 15}

with patch.object(retrain_module, 'RETRAIN_LOG', fake_log):
    _log_result(fake_before, fake_after, fake_stats, improved=True)
    with open(fake_log) as f:
        log = json.load(f)

# Test 12: Log file created with one entry
check('Log file created with one entry', len(log) == 1, f'entries={len(log)}')

# Test 13: Log entry has all required keys
required_log_keys = [
    'timestamp', 'improved', 'f1_before', 'f1_after',
    'f1_hv_before', 'f1_hv_after', 'f1_prov_before', 'f1_prov_after',
    'attack_recall_before', 'attack_recall_after', 'dataset_stats'
]
check(
    'Log entry has all required keys',
    all(k in log[0] for k in required_log_keys),
    f'missing: {[k for k in required_log_keys if k not in log[0]]}'
)

# Test 14: Log appends on second write
with patch.object(retrain_module, 'RETRAIN_LOG', fake_log):
    _log_result(fake_before, fake_after, fake_stats, improved=False)
    with open(fake_log) as f:
        log2 = json.load(f)
check(
    'Log appends entries — does not overwrite',
    len(log2) == 2,
    f'entries={len(log2)}'
)

# ── TEST GROUP 5: retrain_state ───────────────────────────────
print('\n--- TEST GROUP 5: retrain_state ---')

# Test 15: retrain_state has all required keys
required_state_keys = ['last_run_ts', 'last_f1_before', 'last_f1_after', 'status', 'message']
check(
    'retrain_state has all required keys',
    all(k in retrain_state for k in required_state_keys),
    f'got keys: {list(retrain_state.keys())}'
)

# Final summary
print('\n' + '=' * 70)
print(f'RESULTS: {passed}/{passed + failed} tests passed')
if failed == 0:
    print('✅ ALL TESTS PASSED')
else:
    print(f'❌ {failed} tests FAILED')
print('=' * 70)

shutil.rmtree(tmp_dir)
print(f'\nCleaned up temp directory: {tmp_dir}')
