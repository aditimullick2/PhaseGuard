import json
import os
import sys

sys.path.insert(0, 'd:/PhaseGuard/apps/api/factcheck')
try:
    from stress_1000_data import SCENARIOS
except ImportError:
    print("Could not import SCENARIOS")
    sys.exit(1)

out_path = 'd:/PhaseGuard/apps/api/ai_training/stress_dataset.jsonl'
with open(out_path, 'w', encoding='utf-8') as f:
    for text, is_scam, category in SCENARIOS:
        # Our training script expects "text" and "label"
        label = "SCAM" if is_scam else "NORMAL"
        record = {"text": text, "label": label, "category": category}
        f.write(json.dumps(record) + '\n')

print(f"Exported {len(SCENARIOS)} stress test scenarios to {out_path}")
