import os
import numpy as np
import tensorflow as tf
import librosa
from pathlib import Path
import sys

sys.stdout.reconfigure(encoding='utf-8')

ASSETS_DIR = Path('d:/PhaseGuard/apps/flutter/assets/models')
DEEPFAKE_MODEL_PATH = ASSETS_DIR / 'deepfake_detector.tflite'
SYNTHETIC_DIR = Path('d:/PhaseGuard/apps/api/samples/synthetic')
USER_VOICES_DIR = Path('d:/PhaseGuard/apps/api/samples/user_voices')

interpreter = tf.lite.Interpreter(model_path=str(DEEPFAKE_MODEL_PATH))
interpreter.allocate_tensors()
inp_det = interpreter.get_input_details()[0]
out_det = interpreter.get_output_details()[0]

def extract_spectrogram_and_dsp(audio_chunk):
    D = librosa.stft(audio_chunk, n_fft=256, hop_length=128, center=False)
    mag = np.abs(D)
    mag_db = librosa.amplitude_to_db(mag, ref=np.max)
    if np.max(mag_db) != np.min(mag_db):
        mag_db = (mag_db - np.min(mag_db)) / (np.max(mag_db) - np.min(mag_db))
        
    # DSP: Calculate Pitch Variance & Silence Ratio
    zero_frames = 0
    dominant_bins = []
    
    for f in range(mag_db.shape[1]):
        frame = mag_db[:, f]
        energy = np.mean(frame)
        if energy < 0.05:
            zero_frames += 1
        else:
            dominant_bins.append(np.argmax(frame))
            
    silence_ratio = zero_frames / float(mag_db.shape[1])
    variance = np.var(dominant_bins) if dominant_bins else 0.0
    
    mag_db = mag_db.T
    expected_frames = 124
    if mag_db.shape[0] < expected_frames:
        mag_db = np.pad(mag_db, ((0, expected_frames - mag_db.shape[0]), (0, 0)))
    elif mag_db.shape[0] > expected_frames:
        mag_db = mag_db[:expected_frames, :]
    return mag_db, variance, silence_ratio

def infer_audio(filepath):
    try:
        audio, _ = librosa.load(filepath, sr=16000, duration=1.0)
        if len(audio) < 16000:
            audio = np.pad(audio, (0, 16000 - len(audio)))
        elif len(audio) > 16000:
            audio = audio[:16000]
            
        spec, variance, silence_ratio = extract_spectrogram_and_dsp(audio)
        inp = np.float32(spec).reshape(1, 124, 129, 1)
        interpreter.set_tensor(inp_det['index'], inp)
        interpreter.invoke()
        nn_conf = interpreter.get_tensor(out_det['index'])[0][0]
        
        final_conf = float(nn_conf)
        
        # Apply DSP rules
        is_unnatural = (0.0 < variance < 8.0)
        is_silent = (silence_ratio > 0.3)
        
        if nn_conf > 0.35 and (is_unnatural or is_silent):
            final_conf = min(1.0, nn_conf + 0.4)
        elif variance > 25.0:
            final_conf = max(0.0, nn_conf - 0.3)
            
        return final_conf, variance, silence_ratio
    except Exception as e:
        print(e)
        return -1.0, 0, 0

print("=" * 75)
print("  TESTING TFLITE 2D CNN + DSP HEURISTIC ON ACTUAL AUDIO FILES")
print("=" * 75)

print("--- REAL HUMAN VOICES ---")
human_files = list(USER_VOICES_DIR.glob('*.mp3'))[:5]
for f in human_files:
    score, v, s = infer_audio(f)
    pred = "DEEPFAKE" if score >= 0.5 else "HUMAN"
    print(f"{f.name[:30]:<30} | Score: {score:.4f} (Var: {v:>5.1f}) -> {pred}")

print("\n--- SYNTHETIC/DEEPFAKE VOICES ---")
fake_files = list(SYNTHETIC_DIR.glob('*.mp3'))[:5]
for f in fake_files:
    score, v, s = infer_audio(f)
    pred = "DEEPFAKE" if score >= 0.5 else "HUMAN"
    print(f"{f.name[:30]:<30} | Score: {score:.4f} (Var: {v:>5.1f}) -> {pred}")
