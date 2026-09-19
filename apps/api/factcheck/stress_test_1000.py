"""
1000 HANDCRAFTED stress-test scenarios.
These are NOT from the training dataset.
Each scenario is written as a real scammer or real legitimate caller would speak.
Categories: scam=True and legitimate=False
"""
import asyncio
import time
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from local_llm import LocalScamClassifier

# ─────────────────────────────────────────────────────────
# 1000 HAND-CRAFTED SCENARIOS
# Format: (transcript, is_scam, category)
# ─────────────────────────────────────────────────────────
from stress_1000_data import SCENARIOS

# ─────────────────────────────────────────────────────────
# RUNNER
# ─────────────────────────────────────────────────────────
async def run():
    classifier = LocalScamClassifier()
    classifier.load_model()

    total = len(SCENARIOS)
    correct = 0
    tp = tn = fp = fn = 0
    cat_fail = {}

    t0 = time.perf_counter()

    for transcript, expected, category in SCENARIOS:
        result = await classifier.predict_instant_scam(transcript)
        predicted = result.get("is_scam", False)

        if expected == predicted:
            correct += 1
            if predicted: tp += 1
            else: tn += 1
        else:
            if predicted: fp += 1
            else:
                fn += 1
                cat_fail[category] = cat_fail.get(category, [])
                cat_fail[category].append(transcript[:100])

    elapsed = time.perf_counter() - t0
    accuracy = correct / total * 100
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0

    print("=" * 65)
    print("  HANDCRAFTED 1000-SCENARIO STRESS TEST")
    print("  (Zero overlap with training dataset)")
    print("=" * 65)
    print(f"  Total Scenarios    : {total}")
    print(f"  Correct            : {correct}")
    print(f"  Accuracy           : {accuracy:.2f}%")
    print(f"  Precision          : {precision:.2%}")
    print(f"  Recall             : {recall:.2%}")
    print(f"  F1 Score           : {f1:.2%}")
    print()
    print(f"  True Positives     : {tp}")
    print(f"  True Negatives     : {tn}")
    print(f"  False Positives    : {fp}")
    print(f"  False Negatives    : {fn}")
    print()
    print(f"  Time               : {elapsed*1000:.0f}ms")
    print(f"  Speed              : {total/elapsed:.0f} detections/sec")
    print("=" * 65)

    if cat_fail:
        print("\n--- MISSED SCAMS BY CATEGORY ---")
        for cat, samples in sorted(cat_fail.items()):
            print(f"\n  [{cat}] ({len(samples)} missed)")
            for s in samples[:3]:
                print(f"    > {s}...")

if __name__ == "__main__":
    asyncio.run(run())
