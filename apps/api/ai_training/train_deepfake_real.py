import os
import sys
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models
import librosa
from pathlib import Path

# Paths
ASSETS_DIR = Path('d:/PhaseGuard/apps/flutter/assets/models')
TFLITE_OUT = ASSETS_DIR / "deepfake_detector.tflite"
SYNTHETIC_DIR = Path('d:/PhaseGuard/apps/api/samples/synthetic')
USER_VOICES_DIR = Path('d:/PhaseGuard/apps/api/samples/user_voices')

SAMPLE_RATE = 16000
SAMPLES = 16000 # 1 second chunk
CHUNKS_PER_FILE = 5

X = []
y = []

def extract_chunks(filepath, label):
    try:
        # Load audio, convert to mono, resample to 16kHz
        audio, _ = librosa.load(filepath, sr=SAMPLE_RATE, mono=True)
        # Skip very short files
        if len(audio) < SAMPLES // 2:
            return 0
            
        chunks = 0
        for i in range(0, len(audio) - SAMPLES + 1, SAMPLES // 2):
            if chunks >= CHUNKS_PER_FILE:
                break
            chunk = audio[i:i + SAMPLES]
            # Normalize chunk
            if np.max(np.abs(chunk)) > 0:
                chunk = chunk / np.max(np.abs(chunk))
            X.append(chunk)
            y.append(label)
            chunks += 1
            
        # If we didn't get enough chunks, pad the last bit
        if chunks == 0 and len(audio) > 0:
            padded = np.pad(audio, (0, max(0, SAMPLES - len(audio))))[:SAMPLES]
            if np.max(np.abs(padded)) > 0:
                padded = padded / np.max(np.abs(padded))
            X.append(padded)
            y.append(label)
            chunks += 1
            
        return chunks
    except Exception as e:
        print(f"Failed to process {filepath}: {e}")
        return 0

print("=" * 60)
print("  TRAINING DEEPFAKE MODEL ON REAL AUDIO DATA")
print("=" * 60)

real_files = list(USER_VOICES_DIR.glob('*.mp3')) + list(USER_VOICES_DIR.glob('*.wav'))
fake_files = list(SYNTHETIC_DIR.glob('*.mp3')) + list(SYNTHETIC_DIR.glob('*.wav'))
fake_files += [Path('d:/PhaseGuard/apps/api/scambait_cloned_voice.wav')]

print(f"Found {len(real_files)} real files and {len(fake_files)} fake files.")

total_real = 0
for f in real_files:
    total_real += extract_chunks(f, 0) # 0 = Human

total_fake = 0
for f in fake_files:
    total_fake += extract_chunks(f, 1) # 1 = Deepfake

if len(X) == 0:
    print("No audio data extracted! Check file paths.")
    sys.exit(1)

X = np.array(X, dtype=np.float32)
X = np.expand_dims(X, axis=-1)
y = np.array(y, dtype=np.float32)

print(f"\nData shape: {X.shape}, Labels: {y.shape}")
print(f"Human chunks: {total_real}, Fake chunks: {total_fake}")

# Need to ensure classes are balanced by weights if necessary
from sklearn.utils.class_weight import compute_class_weight
weights = compute_class_weight('balanced', classes=np.unique(y), y=y)
class_weights = {0: weights[0], 1: weights[1]}
print(f"Class Weights: {class_weights}")

inp = layers.Input(shape=(SAMPLES, 1), name="audio_input")
x = layers.Conv1D(16, 64, strides=4, activation='relu', padding='same')(inp)
x = layers.BatchNormalization()(x)
x = layers.MaxPooling1D(4)(x)

x = layers.Conv1D(32, 32, strides=2, activation='relu', padding='same')(x)
x = layers.BatchNormalization()(x)
x = layers.MaxPooling1D(4)(x)

x = layers.Conv1D(64, 16, strides=2, activation='relu', padding='same')(x)
x = layers.BatchNormalization()(x)
x = layers.MaxPooling1D(4)(x)

x = layers.Flatten()(x)
x = layers.Dense(64, activation='relu')(x)
x = layers.Dropout(0.3)(x)
out = layers.Dense(1, activation='sigmoid', name="is_synthetic")(x)

model = models.Model(inputs=inp, outputs=out)
model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])

print("\nTraining...")
model.fit(X, y, epochs=15, batch_size=8, validation_split=0.2, class_weight=class_weights)

print("\nExporting to TFLite (Float16)...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
tflite_model = converter.convert()

with open(TFLITE_OUT, "wb") as f:
    f.write(tflite_model)

print(f"Model Size -> {len(tflite_model)/1024:.1f} KB")
print("DONE! Actual Deepfake model generated.")
