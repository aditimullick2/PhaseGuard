"""
train_tflite_scam_model.py
===========================
Trains a lightweight on-device scam detector for PhaseGuard Flutter app.

Pipeline:
  1. Load all JSONL datasets (dataset.jsonl, dataset_augmented.jsonl, scam_dataset.jsonl)
  2. Extract text + binary label (scam=1 / not_scam=0)
  3. TF-IDF vectorization (top 3000 tokens, unigrams+bigrams)
  4. 3-layer Dense Neural Network (Keras) with BatchNorm + Dropout
  5. Export to TFLite (float16 quantized, ~1.5 MB)
  6. Save vocab + metadata -> flutter/assets/models/tflite_metadata.json

Outputs (auto-copied to flutter/assets/models/):
  - scam_detector.tflite
  - tflite_metadata.json

Run:
    pip install tensorflow scikit-learn numpy pandas
    python train_tflite_scam_model.py
"""

import json
import os
import re
import sys
import numpy as np
from pathlib import Path
import datetime

# ─────────────────────────────────────────────
# Paths
# ─────────────────────────────────────────────
SCRIPT_DIR = Path(__file__).parent
ASSETS_DIR = SCRIPT_DIR.parent.parent / "flutter" / "assets" / "models"
ASSETS_DIR.mkdir(parents=True, exist_ok=True)

TFLITE_OUT = ASSETS_DIR / "scam_detector.tflite"
META_OUT   = ASSETS_DIR / "tflite_metadata.json"

# ─────────────────────────────────────────────
# 1. Load all datasets
# ─────────────────────────────────────────────
print("=" * 60)
print("  PhaseGuard TFLite Scam Detector — Training Pipeline")
print("=" * 60)

DATASET_FILES = [
    SCRIPT_DIR / "dataset.jsonl",
    SCRIPT_DIR / "dataset_augmented.jsonl",
    SCRIPT_DIR / "scam_dataset.jsonl",
    SCRIPT_DIR / "legitimate_calls.jsonl",
    SCRIPT_DIR / "stress_dataset.jsonl",
]

SCAM_CATEGORIES = {
    "DIGITAL_ARREST", "SEXTORTION", "COURIER_CUSTOMS", "MONEY_MULE",
    "INVESTMENT_FRAUD", "UPI_COLLECT_FRAUD", "ELECTRICITY_THREAT",
    "FAMILY_EMERGENCY", "KYC_SIM_BLOCK", "TECH_SUPPORT",
    "INSURANCE_FRAUD", "CREDIT_CARD_FRAUD", "CHARITY_FRAUD",
    "LOTTERY_FRAUD", "SCAM",
}

def normalize_text(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r"[^\w\s\u0900-\u097f]", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text

texts, labels = [], []

for fp in DATASET_FILES:
    if not fp.exists():
        print(f"  [SKIP] {fp.name} not found")
        continue
    loaded = 0
    with open(fp, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue

            # Format A: instruction/input/output (from dataset.jsonl)
            if "input" in rec and "output" in rec:
                raw_text = rec.get("input", "")
                try:
                    out = json.loads(rec["output"])
                    is_scam = bool(out.get("is_scam", False))
                except Exception:
                    is_scam = False

            # Format B: text/label/category (from scam_dataset.jsonl)
            elif "text" in rec and "label" in rec:
                raw_text = rec.get("text", "")
                lbl = rec.get("label", "NORMAL").upper()
                cat = rec.get("category", "UNKNOWN").upper()
                is_scam = (lbl == "SCAM") or (cat in SCAM_CATEGORIES)

            else:
                continue

            text = normalize_text(raw_text)
            if len(text) < 5:
                continue

            texts.append(text)
            labels.append(1 if is_scam else 0)
            loaded += 1

    print(f"  [OK] {fp.name}  ->  {loaded} records")

print(f"\n  Total samples : {len(texts)}")
print(f"  Scam          : {sum(labels)}")
print(f"  Not scam      : {len(labels) - sum(labels)}")

assert len(texts) >= 100, "Not enough data! Check dataset paths."

# ─────────────────────────────────────────────
# 2. TF-IDF Vectorization
# ─────────────────────────────────────────────
print("\n[2/6] Building TF-IDF features...")

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.model_selection import train_test_split

VOCAB_SIZE = 3000

vectorizer = TfidfVectorizer(
    max_features=VOCAB_SIZE,
    ngram_range=(1, 2),
    sublinear_tf=True,
    min_df=2,
    analyzer="word",
    token_pattern=r"(?u)\b\w+\b",
)

X = vectorizer.fit_transform(texts).toarray().astype(np.float32)
y = np.array(labels, dtype=np.float32)

print(f"  Feature matrix : {X.shape}")
print(f"  Vocab size     : {len(vectorizer.vocabulary_)}")

# ─────────────────────────────────────────────
# 3. Train / Val / Test split
# ─────────────────────────────────────────────
print("\n[3/6] Splitting data (70/15/15)...")

X_tv, X_test, y_tv, y_test = train_test_split(
    X, y, test_size=0.15, stratify=y, random_state=42
)
X_train, X_val, y_train, y_val = train_test_split(
    X_tv, y_tv, test_size=0.176, stratify=y_tv, random_state=42  # 0.176 * 0.85 ≈ 0.15
)

print(f"  Train : {len(X_train)}  |  Val : {len(X_val)}  |  Test : {len(X_test)}")

# ─────────────────────────────────────────────
# 4. Build & Train Keras Model
# ─────────────────────────────────────────────
print("\n[4/6] Building 3-layer neural network...")

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

tf.random.set_seed(42)
np.random.seed(42)

inp = keras.Input(shape=(VOCAB_SIZE,), name="tfidf_input")

x = layers.Dense(512, name="dense_1")(inp)
x = layers.BatchNormalization(name="bn_1")(x)
x = layers.Activation("relu")(x)
x = layers.Dropout(0.3, name="drop_1")(x)

x = layers.Dense(256, name="dense_2")(x)
x = layers.BatchNormalization(name="bn_2")(x)
x = layers.Activation("relu")(x)
x = layers.Dropout(0.2, name="drop_2")(x)

x = layers.Dense(128, activation="relu", name="dense_3")(x)
x = layers.Dropout(0.1, name="drop_3")(x)

out = layers.Dense(1, activation="sigmoid", name="scam_prob")(x)

model = keras.Model(inputs=inp, outputs=out, name="PhaseGuard_ScamDetector")
model.summary()

# Class weights for imbalance
n_scam     = max(int(sum(y_train)), 1)
n_clean    = max(int(len(y_train) - n_scam), 1)
total      = len(y_train)
class_weight = {
    0: total / (2.0 * n_clean),
    1: total / (2.0 * n_scam),
}
print(f"  Class weights  ->  0 (clean): {class_weight[0]:.3f}  |  1 (scam): {class_weight[1]:.3f}")

model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=1e-3),
    loss="binary_crossentropy",
    metrics=[
        "accuracy",
        keras.metrics.Precision(name="precision"),
        keras.metrics.Recall(name="recall"),
        keras.metrics.AUC(name="auc"),
    ],
)

callbacks = [
    keras.callbacks.EarlyStopping(
        monitor="val_auc", patience=8, restore_best_weights=True, mode="max"
    ),
    keras.callbacks.ReduceLROnPlateau(
        monitor="val_loss", factor=0.5, patience=4, min_lr=1e-6, verbose=1
    ),
]

print("\n[Training...]")
history = model.fit(
    X_train, y_train,
    validation_data=(X_val, y_val),
    epochs=60,
    batch_size=64,
    class_weight=class_weight,
    callbacks=callbacks,
    verbose=1,
)

# ─────────────────────────────────────────────
# 5. Evaluate
# ─────────────────────────────────────────────
print("\n[5/6] Evaluating on test set...")

from sklearn.metrics import (
    classification_report, confusion_matrix, roc_auc_score, accuracy_score
)

y_prob = model.predict(X_test, batch_size=128).flatten()
y_pred = (y_prob >= 0.5).astype(int)

test_acc = accuracy_score(y_test, y_pred)
test_auc = roc_auc_score(y_test, y_prob)

print("\n" + "=" * 60)
print("  TEST RESULTS")
print("=" * 60)
print(f"  Accuracy  : {test_acc * 100:.2f}%")
print(f"  ROC-AUC   : {test_auc:.4f}")
print()
print(classification_report(y_test, y_pred, target_names=["NOT_SCAM", "SCAM"]))
print("Confusion Matrix:")
cm = confusion_matrix(y_test, y_pred)
print(cm)

# ─────────────────────────────────────────────
# 6. Convert to TFLite (float16)
# ─────────────────────────────────────────────
print("\n[6/6] Converting to TFLite (float16 quantized)...")

converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
tflite_model = converter.convert()

with open(TFLITE_OUT, "wb") as f:
    f.write(tflite_model)

size_kb = len(tflite_model) / 1024
print(f"  Saved   -> {TFLITE_OUT}")
print(f"  Size    -> {size_kb:.1f} KB  ({size_kb / 1024:.2f} MB)")

# Verify TFLite
print("\n  Verifying TFLite inference...")
interp = tf.lite.Interpreter(model_path=str(TFLITE_OUT))
interp.allocate_tensors()
inp_det = interp.get_input_details()[0]
out_det = interp.get_output_details()[0]
print(f"  Input  : shape={inp_det['shape']}  dtype={inp_det['dtype']}")
print(f"  Output : shape={out_det['shape']}  dtype={out_det['dtype']}")

sample_in = X_test[:1].astype(np.float32)
interp.set_tensor(inp_det["index"], sample_in)
interp.invoke()
tflite_score = float(interp.get_tensor(out_det["index"])[0][0])
keras_score  = float(model.predict(sample_in, verbose=0)[0][0])
print(f"  Sample -> Keras: {keras_score:.4f}  TFLite: {tflite_score:.4f}  [OK]")

# ─────────────────────────────────────────────
# 7. Save metadata + vocabulary for Flutter
# ─────────────────────────────────────────────
vocab = {k: int(v) for k, v in vectorizer.vocabulary_.items()}
idf   = vectorizer.idf_.tolist()

metadata = {
    "version":        "2.0.0",
    "model_name":     "PhaseGuard_ScamDetector",
    "created_at":     datetime.datetime.now().isoformat(),
    "vocab_size":     VOCAB_SIZE,
    "ngram_range":    [1, 2],
    "threshold":      0.5,
    "input_dtype":    "float32",
    "input_shape":    [1, VOCAB_SIZE],
    "output_shape":   [1, 1],
    "output_meaning": "scam_probability  (0.0=safe  1.0=scam)",
    "training": {
        "n_train":       int(len(X_train)),
        "n_val":         int(len(X_val)),
        "n_test":        int(len(X_test)),
        "test_accuracy": float(round(test_acc, 5)),
        "test_auc":      float(round(test_auc, 5)),
        "n_scam":        int(sum(labels)),
        "n_clean":       int(len(labels) - sum(labels)),
        "confusion_matrix": cm.tolist(),
    },
    "scam_categories": sorted(list(SCAM_CATEGORIES)),
    "vocabulary":      vocab,
    "idf_weights":     idf,
}

with open(META_OUT, "w", encoding="utf-8") as f:
    json.dump(metadata, f, indent=2, ensure_ascii=False)

print(f"\n  Metadata saved -> {META_OUT}")

print("\n" + "=" * 60)
print("  DONE! PhaseGuard TFLite Scam Detector ready")
print(f"  Accuracy  : {test_acc * 100:.2f}%")
print(f"  AUC       : {test_auc:.4f}")
print(f"  Size      : {size_kb:.1f} KB")
print("=" * 60)
print()
print("  Next steps:")
print("  1. cd d:\\PhaseGuard\\apps\\flutter")
print("  2. flutter run  (model auto-loads from assets/models/)")
