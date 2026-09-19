"""
dsp/local_ml.py — Local offline Hugging Face Inference for deepfake detection.

Uses a pre-trained Audio Classification model downloaded to the local machine
to detect spoofed/AI-generated audio.
"""
import io
import logging
import time
import numpy as np
import scipy.io.wavfile
import warnings

# Suppress HuggingFace warnings for cleaner logs
warnings.filterwarnings("ignore", category=UserWarning)

logger = logging.getLogger(__name__)

# Singleton pipeline instances
_deepfake_pipeline = None

def load_models():
    """
    Loads the Hugging Face audio classification model locally.
    Downloads the model to ~/.cache/huggingface on the first run.
    """
    global _deepfake_pipeline
    if _deepfake_pipeline is None:
        try:
            logger.info("Loading local ML deepfake detection model...")
            from transformers import pipeline
            import torch
            
            # Using a robust model for ASVSpoof
            model_id = "abhishtagatya/wav2vec2-base-960h-itw-deepfake"
            device = 0 if torch.cuda.is_available() else -1
            
            _deepfake_pipeline = pipeline(
                "audio-classification", 
                model=model_id, 
                device=device,
                framework="pt"
            )
            logger.info("Local ML deepfake detection model loaded successfully.")
        except Exception as e:
            logger.error(f"Failed to load local ML model: {e}")
            _deepfake_pipeline = False # Mark as failed

async def analyze_audio_local(window: np.ndarray, fs: int = 16_000) -> dict:
    """
    Run local inference using the transformers pipeline.
    Returns a dictionary with the ML analysis result.
    """
    global _deepfake_pipeline
    
    # Lazy load the model on first request
    if _deepfake_pipeline is None:
        load_models()
        
    t0 = time.perf_counter()

    # Fallback if model failed to load
    if _deepfake_pipeline is False:
        return fallback_dsp(window, fs, t0)

    try:
        # Convert float32 numpy array to 16-bit PCM WAV in memory
        # Transformers pipeline accepts raw audio arrays if properly formatted,
        # but to be completely safe with preprocessing, we can pass it as a float32 array 
        # or dict based on librosa/transformers standards.
        
        # Pipeline typically expects sampling rate of 16kHz float32.
        # Ensure it's a 1D float32 array
        audio_array = window.astype(np.float32)
        
        # Run inference
        results = _deepfake_pipeline(audio_array)
        
        # Parse results — model outputs sorted by score descending
        # Labels: 'spoof' = AI-generated, 'bona-fide' = real human
        top_label = results[0].get("label", "unknown").lower()
        
        # Always use the 'spoof' label score as the synthetic probability
        spoof_score = 0.0
        for r in results:
            if "spoof" in r.get("label", "").lower() or "fake" in r.get("label", "").lower():
                spoof_score = r.get("score", 0.0)
                break
        
        # If no explicit spoof label found, infer from top label
        if spoof_score == 0.0:
            if "spoof" in top_label or "fake" in top_label:
                spoof_score = results[0].get("score", 0.5)
            else:
                spoof_score = 1.0 - results[0].get("score", 0.5)
        
        score = spoof_score  # 0 = human, 1 = AI/synthetic
        is_synthetic = score > 0.5
        
        # FIX: False Positive Override
        # Heavily compressed audio (like WhatsApp) often fools ML models into thinking it's synthetic.
        # If the ML model says it's fake, we cross-verify with our DSP Micro-Tremor engine.
        # If physiological human tremor is detected, it overrides the ML prediction.
        if is_synthetic:
            from dsp.micro_tremor import compute_tremor_score
            tremor_res = compute_tremor_score(window, fs)
            if tremor_res.get('has_tremor', False):
                logger.info(f"ML predicted FAKE ({score:.2f}) but DSP Micro-Tremor detected human physiology. Overriding to REAL.")
                is_synthetic = False
                top_label = "bonafide (dsp_override)"
                score = 0.85  # Assign a high confidence for the override
        
        return {
            "status": "success",
            "is_synthetic": is_synthetic,
            "top_label": top_label,
            "score": score,
            "compute_ms": (time.perf_counter() - t0) * 1000,
            "raw_output": results,
            "model_used": "local_wav2vec2_deepfake"
        }
        
    except Exception as e:
        logger.warning(f"Local ML Inference Error: {e}")
        return fallback_dsp(window, fs, t0)

def fallback_dsp(window: np.ndarray, fs: int, t0: float) -> dict:
    """Fallback to DSP if local ML fails for any reason."""
    logger.info("Falling back to local DSP ensemble for deepfake detection")
    from dsp.ensemble_score import compute_ensemble
    from dsp.micro_tremor import compute_tremor_score
    from dsp.phase_dispersion import compute_pdi
    
    try:
        window_size = 512
        hop_size = 256
        
        pdi_scores = []
        for i in range(0, len(window) - window_size, hop_size):
            win = window[i:i + window_size]
            res = compute_pdi(win, fs)
            if res['n_triads_analysed'] > 0:
                pdi_scores.append(res['pdi_score'])
                
        avg_pdi = float(np.mean(pdi_scores)) if pdi_scores else 0.5
        
        tremor_res = compute_tremor_score(window, fs)
        
        ensemble_res = compute_ensemble(avg_pdi, tremor_res['tremor_energy'], window, fs)
        
        is_synthetic = ensemble_res['label'] == 'SYNTHETIC'
        score = 1.0 - ensemble_res['ensemble_score'] if is_synthetic else ensemble_res['ensemble_score']
        
        return {
            "status": "success",
            "is_synthetic": is_synthetic,
            "top_label": "spoofed" if is_synthetic else "bonafide",
            "score": score,
            "compute_ms": (time.perf_counter() - t0) * 1000,
            "raw_output": ensemble_res,
            "model_used": "local_dsp_ensemble"
        }
    except Exception as e:
        logger.error(f"DSP Fallback failed: {e}")
        return {"status": "error", "message": "All ML models and DSP fallback failed"}
