import os, sys, sqlite3, time

os.environ['ADAPTIVE_DB_PATH'] = 'test_p4_verify.db'
import services.adaptive_store as store
store.init_db()

# Seed: 2 human-verified HESITATE + 3 provisional BLOCK
old = time.time() - (49 * 3600)

conn = sqlite3.connect('test_p4_verify.db')
conn.execute(
    "INSERT INTO cases (prompt,verdict,risk_score,label,rlhf_label,rlhf_pending,created_at,prompt_hash) VALUES ('attack1','HESITATE',0.8,1,1,0,?,?)",
    (old, 'h1')
)
conn.execute(
    "INSERT INTO cases (prompt,verdict,risk_score,label,rlhf_label,rlhf_pending,created_at,prompt_hash) VALUES ('safe1','HESITATE',0.4,1,0,0,?,?)",
    (old, 'h2')
)
conn.execute(
    "INSERT INTO cases (prompt,verdict,risk_score,label,rlhf_label,rlhf_pending,created_at,prompt_hash) VALUES ('block1','BLOCK',0.9,1,NULL,0,?,?)",
    (old, 'b1')
)
conn.execute(
    "INSERT INTO cases (prompt,verdict,risk_score,label,rlhf_label,rlhf_pending,created_at,prompt_hash) VALUES ('block2','BLOCK',0.9,1,NULL,0,?,?)",
    (old, 'b2')
)
conn.execute(
    "INSERT INTO cases (prompt,verdict,risk_score,label,rlhf_label,rlhf_pending,created_at,prompt_hash) VALUES ('block3','BLOCK',0.9,1,NULL,0,?,?)",
    (old, 'b3')
)
conn.commit()
conn.close()

from services.retrain_bert import prepare_training_data
train_ds, test_ds, stats = prepare_training_data()

print(f'total={stats["total"]}')
print(f'human_verified={stats["human_verified"]}')
print(f'provisional={stats["provisional"]}')
# 2 human * 2 + 3 provisional * 1 = 7 total rows
print(f'weighting_correct={stats["total"] == 7}')

os.remove('test_p4_verify.db')
