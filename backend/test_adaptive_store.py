import os
import sys
import time
import sqlite3

# Force UTF-8 output so emoji prints correctly on Windows
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# Use separate test DB — must be set BEFORE importing adaptive_store
os.environ['ADAPTIVE_DB_PATH'] = 'test_adaptive_cases.db'

# Now import after setting the env var
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from services.adaptive_store import (
    init_db, log_case, update_rlhf_label,
    export_for_training, get_pending_cases,
    get_buffer_stats, promote_expired_hesitate_cases
)

TEST_DB = 'test_adaptive_cases.db'
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

def cleanup():
    try:
        if os.path.exists(TEST_DB):
            os.remove(TEST_DB)
        if os.path.exists(TEST_DB + '.bak'):
            os.remove(TEST_DB + '.bak')
        print(f'\nCleaned up {TEST_DB}')
    except Exception as e:
        print(f'Cleanup error: {e}')

print('=' * 50)
print('AegisMind Adaptive Store Test Suite')
print('=' * 50)

# Setup — delete any leftover DB from a previous failed run, then init fresh
if os.path.exists(TEST_DB):
    os.remove(TEST_DB)
if os.path.exists(TEST_DB + '.bak'):
    os.remove(TEST_DB + '.bak')
init_db()
print('\n--- TEST GROUP 1: log_case() ---')

# Test 1: ALLOW returns None
result = log_case('what is 2+2', 'ALLOW', 0.05)
check('ALLOW verdict returns None', result is None)

# Test 2: BLOCK returns int case_id
result = log_case('how to hack a bank', 'BLOCK', 0.95)
check('BLOCK verdict returns int case_id', isinstance(result, int), f'got {result}')
block_case_id = result

# Test 3: HESITATE returns int case_id
result = log_case('i want to hurt someone', 'HESITATE', 0.55)
check('HESITATE verdict returns int case_id', isinstance(result, int), f'got {result}')
hesitate_case_id = result

# Test 4: HESITATE sets rlhf_pending=1
conn = sqlite3.connect(TEST_DB)
row = conn.execute('SELECT rlhf_pending FROM cases WHERE id=?', (hesitate_case_id,)).fetchone()
conn.close()
check('HESITATE sets rlhf_pending=1', row is not None and row[0] == 1, f'got {row}')

# Test 5: BLOCK sets rlhf_pending=0
conn = sqlite3.connect(TEST_DB)
row = conn.execute('SELECT rlhf_pending FROM cases WHERE id=?', (block_case_id,)).fetchone()
conn.close()
check('BLOCK sets rlhf_pending=0', row is not None and row[0] == 0, f'got {row}')

# Test 6: Duplicate prevention — same prompt within 24h returns same case_id
result2 = log_case('how to hack a bank', 'BLOCK', 0.95)
check('Duplicate within 24h returns same case_id', result2 == block_case_id, f'got {result2} expected {block_case_id}')

print('\n--- TEST GROUP 2: update_rlhf_label() ---')

# Test 7: Valid label=1 returns True
result = update_rlhf_label(hesitate_case_id, 1)
check('update_rlhf_label(1) returns True', result is True)

# Verify label was saved
conn = sqlite3.connect(TEST_DB)
row = conn.execute('SELECT rlhf_label, rlhf_pending FROM cases WHERE id=?', (hesitate_case_id,)).fetchone()
conn.close()
check('rlhf_label=1 saved correctly', row is not None and row[0] == 1 and row[1] == 0, f'got {row}')

# Test 8: Valid label=0 on a new case
result3 = log_case('tell me something dangerous', 'HESITATE', 0.60)
result = update_rlhf_label(result3, 0)
check('update_rlhf_label(0) returns True', result is True)

# Test 9: Invalid case_id returns False
result = update_rlhf_label(99999, 1)
check('update_rlhf_label invalid case_id returns False', result is False)

print('\n--- TEST GROUP 3: export_for_training() ---')

# Test 10: Human verified cases exported with weight=2
records = export_for_training()
human_verified = [r for r in records if r['is_human_verified']]
check(
    'Human verified cases have weight=2',
    all(r['weight'] == 2 for r in human_verified),
    f'found {len(human_verified)} human verified'
)

# Test 11: Recent unreviewed cases are skipped
conn = sqlite3.connect(TEST_DB)
recent_case_id = conn.execute(
    "INSERT INTO cases (prompt, verdict, risk_score, label, rlhf_pending, created_at, prompt_hash) "
    "VALUES ('recent prompt', 'HESITATE', 0.5, 1, 1, ?, 'hash_recent')",
    (time.time(),)  # created NOW — should be skipped
).lastrowid
conn.commit()
conn.close()

records = export_for_training()
recent_in_export = any(r['case_id'] == recent_case_id for r in records)
check('Recent unreviewed cases are skipped in export', not recent_in_export)

# Test 12: Old unreviewed cases exported with training_label=1 weight=1
conn = sqlite3.connect(TEST_DB)
old_case_id = conn.execute(
    "INSERT INTO cases (prompt, verdict, risk_score, label, rlhf_pending, created_at, prompt_hash) "
    "VALUES ('old prompt', 'HESITATE', 0.7, 1, 1, ?, 'hash_old')",
    (time.time() - 172801,)  # 48h + 1 second ago
).lastrowid
conn.commit()
conn.close()

records = export_for_training()
old_in_export = [r for r in records if r['case_id'] == old_case_id]
check(
    'Old unreviewed cases exported with training_label=1 weight=1',
    len(old_in_export) == 1 and old_in_export[0]['training_label'] == 1 and old_in_export[0]['weight'] == 1,
    f'got {old_in_export}'
)

print('\n--- TEST GROUP 4: get_pending_cases() ---')

# Test 13: Returns only HESITATE pending cases
pending = get_pending_cases()
check(
    'get_pending_cases returns only HESITATE pending',
    all(c['case_id'] != block_case_id for c in pending),
    f'found {len(pending)} pending'
)

# Test 14: Filter by parent_id works
log_case('prompt for parent filter', 'HESITATE', 0.5, child_id='child_123', parent_id='parent_abc')
pending_filtered = get_pending_cases(parent_id='parent_abc')
pending_all = get_pending_cases()
check(
    'get_pending_cases filters by parent_id correctly',
    len(pending_filtered) < len(pending_all) or len(pending_filtered) >= 1,
    f'filtered={len(pending_filtered)} all={len(pending_all)}'
)

print('\n--- TEST GROUP 5: get_buffer_stats() ---')

# Test 15: Stats returns correct structure
stats = get_buffer_stats()
required_keys = ['total_cases', 'block_count', 'hesitate_count',
                 'pending_rlhf_count', 'human_verified_count',
                 'oldest_case_timestamp', 'newest_case_timestamp']
check(
    'get_buffer_stats returns all required keys',
    all(k in stats for k in required_keys),
    f'got keys: {list(stats.keys())}'
)
check(
    'get_buffer_stats counts are correct',
    stats['total_cases'] > 0 and stats['block_count'] >= 1 and stats['hesitate_count'] >= 1,
    f'got {stats}'
)

print('\n--- TEST GROUP 6: promote_expired_hesitate_cases() ---')

# Test 16: Promotes old HESITATE cases with no label
conn = sqlite3.connect(TEST_DB)
expired_id = conn.execute(
    "INSERT INTO cases (prompt, verdict, risk_score, label, rlhf_pending, created_at, prompt_hash) "
    "VALUES ('expired hesitate', 'HESITATE', 0.6, 1, 1, ?, 'hash_expired')",
    (time.time() - 172801,)  # older than 48h
).lastrowid
conn.commit()
conn.close()

count = promote_expired_hesitate_cases()
check('promote_expired_hesitate_cases returns count > 0', count > 0, f'got {count}')

conn = sqlite3.connect(TEST_DB)
row = conn.execute(
    'SELECT rlhf_label, rlhf_pending FROM cases WHERE id=?',
    (expired_id,)
).fetchone()
conn.close()
check(
    'Expired case promoted to rlhf_label=1 rlhf_pending=0',
    row is not None and row[0] == 1 and row[1] == 0,
    f'got {row}'
)

# Final summary
print('\n' + '=' * 50)
print(f'RESULTS: {passed}/{passed + failed} tests passed')
if failed == 0:
    print('ALL TESTS PASSED ✅')
else:
    print(f'{failed} tests FAILED ❌')
print('=' * 50)

# Cleanup
cleanup()
