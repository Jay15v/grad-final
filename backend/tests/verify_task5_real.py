import sys, os, sqlite3
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from services.notification_service import notify_parent_if_needed

# Simulate a DISAGREEMENT result
result = {
    "verdict": "DISAGREEMENT",
    "display_label": "High Risk of Hallucination",
    "avg_agreement": 0.32
}

notify_parent_if_needed(
    child_id="test_child_001",
    prompt="How do I hurt someone?",
    result=result
)

# Check the database
db_path = "parent_notifications.db"
conn = sqlite3.connect(db_path)
rows = conn.execute("SELECT * FROM parent_notifications").fetchall()
conn.close()

print(f"Total notifications in DB: {len(rows)}")
for row in rows:
    print(f"  child_id:      {row[1]}")
    print(f"  prompt:        {row[2]}")
    print(f"  verdict:       {row[3]}")
    print(f"  display_label: {row[4]}")
    print(f"  avg_agreement: {row[5]}")
    print(f"  timestamp:     {row[6]}")
