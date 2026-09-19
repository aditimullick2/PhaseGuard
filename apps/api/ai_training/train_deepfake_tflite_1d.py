import os
import sys
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models
from pathlib import Path

SCRIPT_DIR = Path('d:/PhaseGuard/apps/api/ai_training')
ASSETS_DIR = Path('d:/PhaseGuard/apps/flutter/assets/models')
TFLITE_OUT = ASSETS_DIR / "deepfake_detector.tflite"

SAMPLE_RATE = 16000
SAMPLES = 16000

print("=" * 60)
print("  Deepfake Audio 1D CNN TFLite Training")
print("=" * 60)

X = []
y = []

for _ in range(200):
    t = np.linspace(0, 1.0, SAMPLES)
    signal = np.sin(2 * np.pi * 440 * t) + np.sin(2 * np.pi * 880 * t) + np.random.randn(SAMPLES) * 0.1
    X.append(signal)
    y.append(0)

for _ in range(200):
    t = np.linspace(0, 1.0, SAMPLES)
    signal = np.sin(2 * np.pi * 440 * t) + np.random.randn(SAMPLES) * 0.01 
    X.append(signal)
    y.append(1)

X = np.array(X, dtype=np.float32)
# Add channel dimension
X = np.expand_dims(X, axis=-1)
y = np.array(y, dtype=np.float32)

print(f"Data shape: {X.shape}, Labels: {y.shape}")

inp = layers.Input(shape=(SAMPLES, 1), name="audio_input")
x = layers.Conv1D(16, 64, strides=4, activation='relu', padding='same')(inp)
x = layers.MaxPooling1D(4)(x)
x = layers.Conv1D(32, 32, strides=2, activation='relu', padding='same')(x)
x = layers.MaxPooling1D(4)(x)
x = layers.Flatten()(x)
x = layers.Dense(32, activation='relu')(x)
out = layers.Dense(1, activation='sigmoid', name="is_synthetic")(x)

model = models.Model(inputs=inp, outputs=out)
model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])

model.fit(X, y, epochs=5, batch_size=32, validation_split=0.2, verbose=1)

converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
tflite_model = converter.convert()

with open(TFLITE_OUT, "wb") as f:
    f.write(tflite_model)

print(f"Model Size -> {len(tflite_model)/1024:.1f} KB")
