import numpy as np
import librosa
from pathlib import Path
from sklearn.preprocessing import StandardScaler

SYNTHETIC_DIR = Path('d:/PhaseGuard/apps/api/samples/synthetic')
USER_VOICES_DIR = Path('d:/PhaseGuard/apps/api/samples/user_voices')

def extract_features(filepath):
    audio, sr = librosa.load(filepath, sr=16000, mono=True, duration=3.0)
    if len(audio) < 16000:
        audio = np.pad(audio, (0, 16000 - len(audio)))

    # MFCC Statistics
    mfccs = librosa.feature.mfcc(y=audio, sr=sr, n_mfcc=13)
    mfcc_mean = np.mean(mfccs, axis=1)
    mfcc_std = np.std(mfccs, axis=1)

    # Chroma
    chroma = librosa.feature.chroma_stft(y=audio, sr=sr)
    chroma_mean = np.mean(chroma)
    chroma_std = np.std(chroma)

    # Spectral features
    sc = librosa.feature.spectral_centroid(y=audio, sr=sr)
    sb = librosa.feature.spectral_bandwidth(y=audio, sr=sr)
    sf = librosa.feature.spectral_flatness(y=audio)
    sc_mean, sc_std = np.mean(sc), np.std(sc)
    sb_mean, sb_std = np.mean(sb), np.std(sb)
    sf_mean = np.mean(sf)

    # ZCR
    zcr = librosa.feature.zero_crossing_rate(audio)
    zcr_mean, zcr_std = np.mean(zcr), np.std(zcr)

    # RMS energy
    rms = librosa.feature.rms(y=audio)
    rms_mean, rms_std = np.mean(rms), np.std(rms)

    feat = np.concatenate([
        mfcc_mean, mfcc_std,
        [chroma_mean, chroma_std, sc_mean, sc_std, sb_mean, sb_std, sf_mean, zcr_mean, zcr_std, rms_mean, rms_std]
    ])
    return feat

print("Extracting features...")
X = []
y = []
for f in list(USER_VOICES_DIR.glob('*.mp3')) + list(USER_VOICES_DIR.glob('*.wav')):
    try: X.append(extract_features(f)); y.append(0)
    except: pass
for f in list(SYNTHETIC_DIR.glob('*.mp3')) + list(SYNTHETIC_DIR.glob('*.wav')):
    try: X.append(extract_features(f)); y.append(1)
    except: pass

X = np.array(X)
y = np.array(y)
print(f"Human: {sum(y==0)}, AI: {sum(y==1)}, Features: {X.shape[1]}")

# Print what separates them
for i, fname in enumerate(['mfcc' + str(j) for j in range(13)] + ['mfcc_std' + str(j) for j in range(13)] + ['chroma_m','chroma_s','sc_m','sc_s','sb_m','sb_s','sf','zcr_m','zcr_s','rms_m','rms_s']):
    hu_mean = X[y==0, i].mean() if sum(y==0) else 0
    ai_mean = X[y==1, i].mean() if sum(y==1) else 0
    if abs(hu_mean - ai_mean) > 1.0:
        print(f"  {fname:<12} | Human={hu_mean:>8.2f}  AI={ai_mean:>8.2f}  Diff={abs(hu_mean-ai_mean):.2f}")
