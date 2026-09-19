import os
import sys
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models
import librosa
from pathlib import Path
from datasets import load_dataset
import soundfile as sf
import io

print("=" * 60)
print("  DOWNLOADING HIGH-QUALITY ASVSPOOF/DEEPFAKE SUBSET...")
print("=" * 60)

ASSETS_DIR = Path('d:/PhaseGuard/apps/flutter/assets/models')
TFLITE_OUT = ASSETS_DIR / "deepfake_detector.tflite"
USER_VOICES_DIR = Path('d:/PhaseGuard/apps/api/samples/user_voices')
SYNTHETIC_DIR = Path('d:/PhaseGuard/apps/api/samples/synthetic')

SAMPLE_RATE = 16000
SAMPLES = 16000
N_FFT = 256
HOP_LENGTH = 128
CHUNKS_PER_FILE = 5

X = []
y = []

def extract_spectrogram(audio_chunk):
    D = librosa.stft(audio_chunk, n_fft=N_FFT, hop_length=HOP_LENGTH, center=False)
    mag = np.abs(D)
    mag_db = librosa.amplitude_to_db(mag, ref=np.max)
    if np.max(mag_db) != np.min(mag_db):
        mag_db = (mag_db - np.min(mag_db)) / (np.max(mag_db) - np.min(mag_db))
    mag_db = mag_db.T
    expected_frames = 124
    if mag_db.shape[0] < expected_frames:
        mag_db = np.pad(mag_db, ((0, expected_frames - mag_db.shape[0]), (0, 0)))
    elif mag_db.shape[0] > expected_frames:
        mag_db = mag_db[:expected_frames, :]
    return mag_db

def process_audio_array(audio, label):
    try:
        if len(audio) < SAMPLES // 2: return 0
        chunks = 0
        for i in range(0, len(audio) - SAMPLES + 1, SAMPLES // 2):
            if chunks >= CHUNKS_PER_FILE: break
            chunk = audio[i:i + SAMPLES]
            X.append(extract_spectrogram(chunk))
            y.append(label)
            chunks += 1
        if chunks == 0 and len(audio) > 0:
            padded = np.pad(audio, (0, max(0, SAMPLES - len(audio))))[:SAMPLES]
            X.append(extract_spectrogram(padded))
            y.append(label)
            chunks += 1
        return chunks
    except Exception: return 0

# 1. Load from HuggingFace
# Hemg/Deepfake-Audio-Dataset -> label 0 is usually real, 1 is fake.
ds = load_dataset('Hemg/Deepfake-Audio-Dataset', split='train', streaming=True)
count_real = 0
count_fake = 0

for item in ds:
    # item['audio'] has 'array', 'sampling_rate'
    audio_arr = item['audio']['array']
    sr = item['audio']['sampling_rate']
    label = float(item['label']) # 0 = real, 1 = fake
    
    # Resample if needed
    if sr != SAMPLE_RATE:
        audio_arr = librosa.resample(audio_arr, orig_sr=sr, target_sr=SAMPLE_RATE)
        
    process_audio_array(audio_arr, label)
    
    if label == 0.0: count_real += 1
    else: count_fake += 1
    
    if count_real >= 300 and count_fake >= 300:
        break

print(f"Downloaded 300 Real and 300 Fake professional audio files!")

# 2. Add local files
real_files = list(USER_VOICES_DIR.glob('*.mp3')) + list(USER_VOICES_DIR.glob('*.wav'))
fake_files = list(SYNTHETIC_DIR.glob('*.mp3')) + list(SYNTHETIC_DIR.glob('*.wav'))

for f in real_files:
    audio, _ = librosa.load(f, sr=SAMPLE_RATE, mono=True)
    process_audio_array(audio, 0.0)

for f in fake_files:
    audio, _ = librosa.load(f, sr=SAMPLE_RATE, mono=True)
    process_audio_array(audio, 1.0)

X = np.array(X, dtype=np.float32)
X = np.expand_dims(X, axis=-1)
y = np.array(y, dtype=np.float32)

print(f"\nData shape: {X.shape}, Labels: {y.shape}")

print("=" * 60)
print("  TRAINING DEEPFAKE 2D CNN ON PRO DATASET")
print("=" * 60)

input_shape = X.shape[1:]
inp = layers.Input(shape=input_shape, name="spectrogram_input")
x = layers.Conv2D(16, (3, 3), activation='relu', padding='same')(inp)
x = layers.MaxPooling2D((2, 2))(x)
x = layers.Conv2D(32, (3, 3), activation='relu', padding='same')(x)
x = layers.MaxPooling2D((2, 2))(x)
x = layers.Conv2D(64, (3, 3), activation='relu', padding='same')(x)
x = layers.MaxPooling2D((2, 2))(x)
x = layers.Flatten()(x)
x = layers.Dense(64, activation='relu')(x)
x = layers.Dropout(0.3)(x)
out = layers.Dense(1, activation='sigmoid', name="is_synthetic")(x)

model = models.Model(inputs=inp, outputs=out)
model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])

model.fit(X, y, epochs=12, batch_size=32, validation_split=0.2)

converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
tflite_model = converter.convert()

with open(TFLITE_OUT, "wb") as f:
    f.write(tflite_model)
    
print(f"Model saved to {TFLITE_OUT}")
