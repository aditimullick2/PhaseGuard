import os
import sys
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models
import librosa
from pathlib import Path

SCRIPT_DIR = Path('d:/PhaseGuard/apps/api/ai_training')
ASSETS_DIR = Path('d:/PhaseGuard/apps/flutter/assets/models')
ASSETS_DIR.mkdir(parents=True, exist_ok=True)
TFLITE_OUT = ASSETS_DIR / "deepfake_detector.tflite"

SAMPLE_RATE = 16000
DURATION = 1.0  # seconds
SAMPLES = int(SAMPLE_RATE * DURATION)
N_MELS = 128
MAX_TIME_STEPS = 32

def get_mel_spectrogram(audio_data, sr=SAMPLE_RATE):
    if len(audio_data) > SAMPLES:
        audio_data = audio_data[:SAMPLES]
    else:
        audio_data = np.pad(audio_data, (0, max(0, SAMPLES - len(audio_data))), "constant")
        
    S = librosa.feature.melspectrogram(
        y=audio_data, sr=sr, n_mels=N_MELS, hop_length=512, n_fft=1024
    )
    S_dB = librosa.power_to_db(S, ref=np.max)
    
    if S_dB.shape[1] > MAX_TIME_STEPS:
        S_dB = S_dB[:, :MAX_TIME_STEPS]
    else:
        S_dB = np.pad(S_dB, ((0, 0), (0, MAX_TIME_STEPS - S_dB.shape[1])), "constant")
        
    S_dB = (S_dB - np.min(S_dB)) / (np.max(S_dB) - np.min(S_dB) + 1e-6)
    return np.expand_dims(S_dB, axis=-1)

print("=" * 60)
print("  Deepfake Audio TFLite Training")
print("=" * 60)

print("[1/4] Generating synthetic training data (POC)...")
X = []
y = []

for _ in range(200):
    t = np.linspace(0, DURATION, SAMPLES)
    signal = np.sin(2 * np.pi * 440 * t) + np.sin(2 * np.pi * 880 * t) + np.random.randn(SAMPLES) * 0.1
    X.append(get_mel_spectrogram(signal))
    y.append(0)

for _ in range(200):
    t = np.linspace(0, DURATION, SAMPLES)
    signal = np.sin(2 * np.pi * 440 * t) + np.random.randn(SAMPLES) * 0.01 
    X.append(get_mel_spectrogram(signal))
    y.append(1)

X = np.array(X, dtype=np.float32)
y = np.array(y, dtype=np.float32)

print(f"Data shape: {X.shape}, Labels: {y.shape}")

print("\n[2/4] Building 2D CNN Model...")
inp = layers.Input(shape=(N_MELS, MAX_TIME_STEPS, 1), name="mel_input")
x = layers.Conv2D(8, (3, 3), activation='relu', padding='same')(inp)
x = layers.MaxPooling2D((2, 2))(x)
x = layers.Conv2D(16, (3, 3), activation='relu', padding='same')(x)
x = layers.MaxPooling2D((2, 2))(x)
x = layers.Flatten()(x)
x = layers.Dense(16, activation='relu')(x)
out = layers.Dense(1, activation='sigmoid', name="is_synthetic")(x)
model = models.Model(inputs=inp, outputs=out)
model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])

print("\n[3/4] Training Model...")
model.fit(X, y, epochs=5, batch_size=32, validation_split=0.2, verbose=1)

print("\n[4/4] Exporting to TFLite...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
tflite_model = converter.convert()

with open(TFLITE_OUT, "wb") as f:
    f.write(tflite_model)

print(f"TFLite Model saved -> {TFLITE_OUT}")
print(f"Model Size -> {len(tflite_model)/1024:.1f} KB")

# Validate
interp = tf.lite.Interpreter(model_path=str(TFLITE_OUT))
interp.allocate_tensors()
print(f"Input Shape: {interp.get_input_details()[0]['shape']}")
print(f"Output Shape: {interp.get_output_details()[0]['shape']}")
print("DONE!")
