import os
import sys
import numpy as np
import tensorflow as tf
import librosa
from pathlib import Path
import json
import re
import time

sys.stdout.reconfigure(encoding='utf-8')

sys.path.insert(0, os.path.abspath('d:/PhaseGuard/apps/api/factcheck'))
from stress_1000_data import SCENARIOS

ASSETS_DIR = Path('d:/PhaseGuard/apps/flutter/assets/models')
SCAM_MODEL_PATH = ASSETS_DIR / 'scam_detector.tflite'
META_PATH = ASSETS_DIR / 'tflite_metadata.json'
DEEPFAKE_MODEL_PATH = ASSETS_DIR / 'deepfake_detector.tflite'

# Paths for Audio
SYNTHETIC_DIR = Path('d:/PhaseGuard/apps/api/samples/synthetic')
USER_VOICES_DIR = Path('d:/PhaseGuard/apps/api/samples/user_voices')

def test_scam_1000():
    print("=" * 70)
    print("  TESTING TFLITE SCAM DETECTOR ON 1000 STRESS SCENARIOS")
    print("=" * 70)
    
    with open(META_PATH, 'r', encoding='utf-8') as f:
        meta = json.load(f)
    
    vocab = meta['vocabulary']
    idf = meta['idf_weights']
    vocab_size = meta['vocab_size']
    
    interpreter = tf.lite.Interpreter(model_path=str(SCAM_MODEL_PATH))
    interpreter.allocate_tensors()
    inp_det = interpreter.get_input_details()[0]
    out_det = interpreter.get_output_details()[0]
    
    def norm(text):
        return re.sub(r"\s+", " ", re.sub(r"[^\w\s\u0900-\u097f]", " ", text.lower())).strip()
        
    correct = 0
    total = len(SCENARIOS)
    
    t0 = time.perf_counter()
    for transcript, expected, _ in SCENARIOS:
        text = norm(transcript)
        tokens = [t for t in text.split() if t]
        unigrams = tokens
        bigrams = [" ".join(tokens[i:i+2]) for i in range(len(tokens)-1)]
        all_tokens = unigrams + bigrams
        
        counts = {}
        for token in all_tokens:
            if token in vocab:
                counts[vocab[token]] = counts.get(vocab[token], 0) + 1
                
        vector = np.zeros(vocab_size, dtype=np.float32)
        for idx, count in counts.items():
            vector[idx] = (1.0 + np.log(count)) * idf[idx]
            
        n = np.linalg.norm(vector)
        if n > 0: vector = vector / n
        
        interpreter.set_tensor(inp_det["index"], np.expand_dims(vector, 0))
        interpreter.invoke()
        score = interpreter.get_tensor(out_det["index"])[0][0]
        
        if bool(score >= 0.5) == expected:
            correct += 1
            
    print(f"Total Scenarios : {total}")
    print(f"Correct         : {correct}")
    print(f"Accuracy        : {(correct/total)*100:.2f}%")
    print(f"Time            : {(time.perf_counter()-t0)*1000:.0f} ms\n")

def test_deepfake_audio():
    print("=" * 70)
    print("  TESTING TFLITE DEEPFAKE DETECTOR ON ACTUAL AUDIO FILES")
    print("=" * 70)
    
    interpreter = tf.lite.Interpreter(model_path=str(DEEPFAKE_MODEL_PATH))
    interpreter.allocate_tensors()
    inp_det = interpreter.get_input_details()[0]
    out_det = interpreter.get_output_details()[0]
    
    def infer_audio(filepath):
        try:
            # Load 1 second at 16000Hz
            audio, _ = librosa.load(filepath, sr=16000, duration=1.0)
            if len(audio) < 16000:
                audio = np.pad(audio, (0, 16000 - len(audio)))
            elif len(audio) > 16000:
                audio = audio[:16000]
                
            inp = np.float32(audio).reshape(1, 16000, 1)
            interpreter.set_tensor(inp_det['index'], inp)
            interpreter.invoke()
            return interpreter.get_tensor(out_det['index'])[0][0]
        except Exception as e:
            return -1.0

    print("--- REAL HUMAN VOICES ---")
    human_files = list(USER_VOICES_DIR.glob('*.mp3'))[:5]
    for f in human_files:
        score = infer_audio(f)
        pred = "DEEPFAKE" if score >= 0.5 else "HUMAN"
        print(f"{f.name[:30]:<30} | Score: {score:.4f} -> {pred}")

    print("\n--- SYNTHETIC/DEEPFAKE VOICES ---")
    fake_files = list(SYNTHETIC_DIR.glob('*.mp3'))[:5]
    for f in fake_files:
        score = infer_audio(f)
        pred = "DEEPFAKE" if score >= 0.5 else "HUMAN"
        print(f"{f.name[:30]:<30} | Score: {score:.4f} -> {pred}")

if __name__ == '__main__':
    test_scam_1000()
    test_deepfake_audio()
