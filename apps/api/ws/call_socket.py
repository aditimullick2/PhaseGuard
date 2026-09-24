"""
ws/call_socket.py — WebSocket handler for live call audio processing.

Route: /ws/call/{call_id}

Per connection, up to four independent asyncio tasks are spawned:
  1. bispectrum_loop      — EXPERIMENTAL, only when DSP_VOICE_DETECTION_ENABLED=true.
                            Runs every ~150ms, emits pdi_update + ensemble_update.
  2. tremor_loop          — EXPERIMENTAL, only when DSP_VOICE_DETECTION_ENABLED=true.
                            Runs every ~1.5s, emits tremor_update.
  3. stt_loop             — PRIMARY feature. Always runs. Emits factcheck_update
                            (Whisper STT → Llama claim extraction → search → verdict).
  4. evidence_capture_loop— Always runs. Polls every 200ms. While the latest verdict
                            is CRITICAL, drains video_frames_buffer → video_frames
                            (permanent record). Decoupled from STT cadence so frames
                            arriving mid-pipeline are never dropped.

All tasks share one AudioBufferManager via independent read cursors.
No task blocks another — each sleeps independently.

WebSocket message types sent to client:
  {type:"connected",         call_id, dsp_enabled, ts}
  {type:"pdi_update",        pdi_score, is_synthetic, ts}          — DSP only
  {type:"tremor_update",     tremor_energy, has_tremor, ts}        — DSP only
  {type:"ensemble_update",   ensemble_score, label, reason, ts}    — DSP only
  {type:"factcheck_update",  status, message, evidence_urls, ts}   — always
  {type:"video_frame_captured", sha256_hash, face_detected, timestamp, ts} — CRITICAL only
  {type:"rate_limited",      retry_after_ms, ts}
  {type:"error",             message, ts}
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

import httpx
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from core.auth import verify_ws_token
from core.config import get_settings
from core.connection_manager import CallState, manager
from dsp.async_dsp import analyze_bispectrum, analyze_ensemble, analyze_tremor
from factcheck.claim_extraction import ClaimExtractor
from factcheck.search import SearchVerifier
from factcheck.stt import STTAccumulator, transcribe_chunk
from factcheck.verdict import generate_verdict
from i18n.language_router import detect_language
from ingestion.browser_mic import BrowserMicIngestion
from intel.number_reputation import get_reputation
from intel.voip_pattern_detector import detect_voip_pattern

logger = logging.getLogger(__name__)
router = APIRouter()


def _ts() -> str:
    return datetime.now(timezone.utc).isoformat()


def _is_valid_transcript(transcript: str) -> bool:
    """
    Validate transcript before processing as a Scambaiter turn.
    
    Rejects:
    - Extremely short (< 5 chars - more strict to avoid garbage)
    - Gibberish (high special char ratio)
    - Single punctuation only
    - Common meaningless single words
    """
    if not transcript or len(transcript.strip()) < 5:
        return False
    
    # Reject single punctuation only
    if transcript.strip() in {'.', ',', '!', '?', '...'}:
        return False
    
    # Reject common meaningless single words
    meaningless_words = {"yes", "no", "ok", "yeah", "uh", "oh", "hm", "hmm", "ah", "is", "my", "the", "a", "an"}
    if transcript.strip().lower() in meaningless_words:
        return False
    
    # Check for excessive special characters (gibberish indicator)
    special_char_ratio = sum(1 for c in transcript if not c.isalnum() and not c.isspace()) / max(len(transcript), 1)
    if special_char_ratio > 0.5:
        return False
    
    return True


def _is_self_echo(transcript: str, recent_ai_responses: list[str]) -> bool:
    """
    Check if STT transcript is too similar to recent AI responses (self-feedback).
    
    This prevents Scambaiter's own audio from triggering a new turn.
    """
    if not recent_ai_responses:
        return False
    
    transcript_normalized = transcript.lower().strip()
    
    for ai_response in recent_ai_responses[-3:]:  # Check last 3 AI responses
        ai_normalized = ai_response.lower().strip()
        
        # Check for high similarity (normalized, removing punctuation)
        import re
        transcript_clean = re.sub(r'[^\w\s]', '', transcript_normalized)
        ai_clean = re.sub(r'[^\w\s]', '', ai_normalized)
        
        # If STT contains > 50% of AI response text, it's likely self-echo
        overlap = sum(1 for word in transcript_clean.split() if word in ai_clean.split())
        if overlap > 0 and len(transcript_clean.split()) > 0:
            overlap_ratio = overlap / len(transcript_clean.split())
            if overlap_ratio > 0.5:
                return True
    
    return False


def _is_duplicate_utterance(transcript: str, recent_utterances: list[str]) -> bool:
    """
    Check if transcript is semantically similar to recent scammer utterances.
    
    Uses normalized text comparison to detect repeated intent.
    """
    if not recent_utterances:
        return False
    
    # Normalize transcript
    normalized = transcript.lower().strip()
    
    for recent in recent_utterances[-3:]:  # Check last 3 utterances
        recent_normalized = recent.lower().strip()
        
        # Exact match
        if normalized == recent_normalized:
            return True
        
        # Similarity check (simple ratio for now)
        if len(normalized) > 5 and len(recent_normalized) > 5:
            # Check if one is substring of the other
            if normalized in recent_normalized or recent_normalized in normalized:
                return True
    
    return False


def _is_similar_response(response: str, recent_responses: list[str]) -> bool:
    """
    Check if AI response is too similar to recent responses.
    
    Prevents repeating the same sentence.
    """
    if not recent_responses:
        return False
    
    normalized = response.lower().strip()
    
    for recent in recent_responses[-2:]:  # Check last 2 responses
        recent_normalized = recent.lower().strip()
        
        # Exact match
        if normalized == recent_normalized:
            return True
        
        # High similarity (simple check)
        if len(normalized) > 10 and len(recent_normalized) > 10:
            similarity = sum(1 for a, b in zip(normalized, recent_normalized) if a == b) / max(len(normalized), len(recent_normalized))
            if similarity > 0.8:  # 80% similarity threshold
                return True
    
    return False


# ── Bispectrum loop ────────────────────────────────────────────────────────────

async def _bispectrum_loop(call_id: str) -> None:
    """
    Independent asyncio task: reads bispectrum-window audio every ~150ms,
    computes PDI + ensemble score, sends updates to client.
    """
    cfg = get_settings()
    session = manager.get_session(call_id)
    if not session:
        return

    buf = session.buffer
    window_n = cfg.bispectrum_window_samples
    cadence = cfg.bispectrum_cadence_ms / 1000.0

    logger.debug("bispectrum_loop started: call_id=%r window=%d cadence=%.3fs",
                 call_id, window_n, cadence)
                 
    uncertain_streak = 0

    while session.state not in (CallState.ENDED,):
        try:
            window = buf.get_window("bispectrum", window_n)
            if window is None:
                # Not enough audio yet — wait and retry
                await asyncio.sleep(cadence / 2)
                continue

            # Run PDI analysis (non-blocking via executor)
            pdi_result = await analyze_bispectrum(window, fs=cfg.sample_rate)
            pdi_score = pdi_result["pdi_score"]

            # Update session peak
            session.latest_pdi = pdi_score
            session.peak_pdi = max(session.peak_pdi, pdi_score)

            # Ensemble score (uses latest tremor too)
            ensemble = await analyze_ensemble(
                pdi_score,
                session.latest_tremor_energy,
                window,
                fs=cfg.sample_rate,
            )
            session.latest_ensemble_label = ensemble["label"]

            await manager.send_json(call_id, {
                "type": "pdi_update",
                "pdi_score": round(pdi_score, 4),
                "is_synthetic": pdi_result["is_synthetic"],
                "n_triads": pdi_result.get("n_triads_analysed", 0),
                "compute_ms": round(pdi_result.get("compute_time_ms", 0), 1),
                "ts": _ts(),
            })

            await manager.send_json(call_id, {
                "type": "ensemble_update",
                "ensemble_score": round(ensemble["ensemble_score"], 4),
                "label": ensemble["label"],
                "disagreement": round(ensemble["disagreement"], 4),
                "reason": ensemble["reason"],
                "ts": _ts(),
            })

            if ensemble["label"] == "UNCERTAIN":
                uncertain_streak += 1
                if uncertain_streak == 3:
                    await manager.send_json(call_id, {
                        "type": "factcheck_update",
                        "status": "WARNING",
                        "message": "⚠️ Audio authenticity uncertain (potential voice cloning or heavy noise). Do not share sensitive information while we fact-check the conversation.",
                        "evidence_urls": [],
                        "ts": _ts(),
                    })
            else:
                uncertain_streak = 0

            await asyncio.sleep(cadence)

        except asyncio.CancelledError:
            logger.debug("bispectrum_loop cancelled: call_id=%r", call_id)
            break
        except Exception as exc:
            logger.error("bispectrum_loop error [%s]: %s", call_id, exc)
            await asyncio.sleep(cadence)


# ── Tremor loop ────────────────────────────────────────────────────────────────

async def _tremor_loop(call_id: str) -> None:
    """
    Independent asyncio task: reads 1.5s audio every ~1.5s,
    computes micro-tremor score, sends update to client.

    Cadence is INDEPENDENT of bispectrum loop — both run concurrently.
    Tremor needs a longer window and slower cadence (see micro_tremor.py).
    """
    cfg = get_settings()
    session = manager.get_session(call_id)
    if not session:
        return

    buf = session.buffer
    window_n = int(cfg.tremor_window_seconds * cfg.sample_rate)
    cadence = cfg.tremor_cadence_seconds

    logger.debug("tremor_loop started: call_id=%r window=%d cadence=%.1fs",
                 call_id, window_n, cadence)

    while session.state not in (CallState.ENDED,):
        try:
            window = buf.get_window("tremor", window_n)
            if window is None:
                await asyncio.sleep(cadence / 2)
                continue

            tremor_result = await analyze_tremor(window, fs=cfg.sample_rate)
            session.latest_tremor_energy = tremor_result["tremor_energy"]
            session.peak_tremor = max(session.peak_tremor, tremor_result["tremor_energy"])

            await manager.send_json(call_id, {
                "type": "tremor_update",
                "tremor_energy": round(tremor_result["tremor_energy"], 4),
                "has_tremor": tremor_result["has_tremor"],
                "peak_tremor_hz": round(tremor_result.get("peak_tremor_hz", 0), 1),
                "compute_ms": round(tremor_result.get("compute_time_ms", 0), 1),
                "ts": _ts(),
            })

            await asyncio.sleep(cadence)

        except asyncio.CancelledError:
            logger.debug("tremor_loop cancelled: call_id=%r", call_id)
            break
        except Exception as exc:
            logger.error("tremor_loop error [%s]: %s", call_id, exc)
            await asyncio.sleep(cadence)


# ── HuggingFace ML loop ────────────────────────────────────────────────────────

async def _hf_ml_loop(call_id: str) -> None:
    """
    Independent asyncio task: reads audio window every ~3.0s,
    sends to HuggingFace Inference API for deepfake/spoof detection.
    """
    cfg = get_settings()
    session = manager.get_session(call_id)
    if not session or not cfg.hf_api_token:
        return

    buf = session.buffer
    # Use a 3s window for better ML context
    window_n = int(3.0 * cfg.sample_rate)
    cadence = 3.0

    from dsp.local_ml import analyze_audio_local

    logger.debug("hf_ml_loop started: call_id=%r window=%d cadence=%.1fs",
                 call_id, window_n, cadence)

    while session.state not in (CallState.ENDED,):
        try:
            window = buf.get_window("hf_ml", window_n)
            if window is None:
                await asyncio.sleep(cadence / 2)
                continue

            # --- HF ML API (Offline) ---
            result = await analyze_audio_local(window, fs=cfg.sample_rate)
            
            if result.get("status") == "success":
                await manager.send_json(call_id, {
                    "type": "hf_ml_update",
                    "is_synthetic": result.get("is_synthetic"),
                    "top_label": result.get("top_label"),
                    "score": round(result.get("score", 0), 4),
                    "compute_ms": round(result.get("compute_ms", 0), 1),
                    "ts": _ts(),
                })
            
            await asyncio.sleep(cadence)

        except asyncio.CancelledError:
            logger.debug("hf_ml_loop cancelled: call_id=%r", call_id)
            break
        except Exception as exc:
            logger.error("hf_ml_loop error [%s]: %s", call_id, exc)
            await asyncio.sleep(cadence)


# ── Continuous Video Evidence Capture loop ─────────────────────────────────────

async def _evidence_capture_loop(call_id: str) -> None:
    """
    Independent asyncio task: polls every 200ms and, whenever the latest
    factcheck verdict is CRITICAL, drains video_frames_buffer into the
    permanent video_frames list.

    Design rationale
    ─────────────────
    Previously this logic lived inside _stt_loop, which runs at STT cadence
    (0.5 s/chunk + 1.5–4 s for the full claim → search → verdict pipeline).
    That created a race: if a screen-share frame arrived *while* the pipeline
    was mid-flight, the capture check would not run for several seconds —
    exactly the timing gap that caused Test 3 failures in live demos.

    By moving capture into its own 200 ms tight loop we guarantee:
      • Frames that land in video_frames_buffer are committed to permanent
        storage within at most 200 ms after the verdict turns CRITICAL.
      • The rolling buffer in video_frames_buffer (last N frames, populated
        by the /frame HTTP endpoint) is drained continuously, not just at
        STT boundaries.
      • Timing mismatches — e.g., "scam" uttered, then screen-share starts
        200 ms–3 s later — are robustly handled regardless of where the STT
        pipeline is in its cycle.

    cadence : 200ms  (5 Hz)  — fast enough to cover any realistic frame rate
              from the client, slow enough to have negligible CPU cost.
    """
    CADENCE = 0.20  # seconds between polls

    session = manager.get_session(call_id)
    if not session:
        return

    logger.debug("evidence_capture_loop started: call_id=%r cadence=%.2fs", call_id, CADENCE)

    while session.state not in (CallState.ENDED,):
        try:
            # Only commit frames while the active verdict is CRITICAL.
            # We intentionally check the *full* factcheck_history so that a
            # SAFE verdict after a CRITICAL one stops further capture — but
            # while CRITICAL persists, every incoming buffer frame is saved.
            if (
                session.factcheck_history
                and session.factcheck_history[-1]["status"] == "CRITICAL"
                and session.video_frames_buffer
            ):
                # Snapshot and drain the rolling buffer atomically.
                # video_frames_buffer keeps receiving new frames from the
                # /frame endpoint (rolling, capped at 3–5); we drain them all
                # into the permanent record on each tick.
                frames_to_commit = session.video_frames_buffer.copy()
                session.video_frames_buffer.clear()
                session.video_frames.extend(frames_to_commit)

                for frame in frames_to_commit:
                    logger.info(
                        "[evidence_capture] Committed frame to permanent record: "
                        "call_id=%r hash=%s face=%s total_permanent=%d",
                        call_id,
                        frame["sha256_hash"][:12],
                        frame["face_detected"],
                        len(session.video_frames),
                    )
                    await manager.send_json(call_id, {
                        "type": "video_frame_captured",
                        "sha256_hash": frame["sha256_hash"],
                        "face_detected": frame["face_detected"],
                        "timestamp": frame["timestamp"],
                        "total_permanent_frames": len(session.video_frames),
                        "ts": _ts(),
                    })

            await asyncio.sleep(CADENCE)

        except asyncio.CancelledError:
            logger.debug("evidence_capture_loop cancelled: call_id=%r", call_id)
            break
        except Exception as exc:
            logger.error("evidence_capture_loop error [%s]: %s", call_id, exc)
            await asyncio.sleep(CADENCE)


# ── Scambaiter Turn Execution ──────────────────────────────────────────────────

async def _fire_scambaiter_turn(call_id: str, caller_speech: str, turn_id: str) -> str:
    """
    Generate and synthesize a scambaiter response, then stream binary audio 
    directly back over the WebSocket.
    
    CRITICAL INVARIANT: ONE turn produces ONE complete response → ONE TTS → ONE audio payload
    
    Args:
        call_id: Call identifier
        caller_speech: Transcribed scammer speech
        turn_id: Unique turn identifier for deduplication
        
    Returns:
        The full AI response text
    """
    session = manager.get_session(call_id)
    if not session or not caller_speech.strip():
        return ""
        
    from scambaiter.persona import generate_scambaiter_response
    from scambaiter.tts import synthesize_speech
    
    logger.info("[SCAMBAITER][%s][%s] LLM_START: input=%r, context=%d", 
               call_id, turn_id, caller_speech[:60], len(session.scambaiter_log))
    
    # 1. Generate COMPLETE text response first (no streaming per sentence)
    full_response_text = await generate_scambaiter_response(
        caller_speech=caller_speech,
        exchange_history=session.scambaiter_log,
        call_id=call_id
    )
    
    if not full_response_text or not full_response_text.strip():
        logger.warning("[SCAMBAITER][%s][%s] LLM_EMPTY_RESPONSE", call_id, turn_id)
        return ""
    
    logger.info("[SCAMBAITER][%s][%s] LLM_COMPLETE: response_chars=%d", 
               call_id, turn_id, len(full_response_text))
    
    # Broadcast the complete text exchange to frontend
    try:
        await manager.send_json(call_id, {
            "type": "scambaiter_turn",
            "caller_text": caller_speech,
            "ai_text": full_response_text.strip(),
            "ts": _ts(),
        })
    except Exception as exc:
        logger.warning("[SCAMBAITER][%s][%s] JSON_SEND_FAILED: %s", call_id, turn_id, exc)

    # 2. Check for self-echo: if STT transcript is similar to our own recent AI response
    if _is_self_echo(caller_speech, session.recent_ai_responses):
        logger.warning("[SCAMBAITER][%s][%s] SELF_ECHO_DROPPED: transcript too similar to AI response", 
                     call_id, turn_id)
        return full_response_text  # Still return text but don't TTS
    
    # 3. Check if this response was already played (deduplication)
    import hashlib
    response_hash = hashlib.md5(full_response_text.strip().encode()).hexdigest()
    
    if response_hash in session.recent_response_hashes:
        logger.warning("[SCAMBAITER][%s][%s] DUPLICATE_TURN_IGNORED: hash=%s", 
                     call_id, turn_id, response_hash[:8])
        return full_response_text  # Still return text but don't TTS
    
    # 4. Synthesize audio ONCE for the COMPLETE response
    logger.info("[SCAMBAITER][%s][%s] TTS_START: voice_id=%r, response_len=%d",
               call_id, turn_id, session.user_voice_id, len(full_response_text))

    # Removed voice_id requirement - TTS will use fallback (gTTS) if no voice configured
    # This allows Scambaiter to work even without voice enrollment
    audio_bytes = await synthesize_speech(full_response_text, call_id=call_id)
    
    if not audio_bytes:
        logger.warning("[SCAMBAITER][%s][%s] TTS_FAILED: no audio generated", call_id, turn_id)
        return full_response_text
    
    logger.info("[SCAMBAITER][%s][%s] TTS_REQUEST_SENT: voice_id=%r",
               call_id, turn_id, session.user_voice_id)
    logger.info("[SCAMBAITER][%s][%s] TTS_COMPLETE: bytes=%d",
               call_id, turn_id, len(audio_bytes))

    # 5. Add to response hashes BEFORE sending audio to prevent duplicate sends
    session.recent_response_hashes.add(response_hash)
    if len(session.recent_response_hashes) > 10:
        session.recent_response_hashes.pop()

    # 6. Add to recent responses (after TTS for context)
    session.recent_ai_responses.append(full_response_text.strip())
    if len(session.recent_ai_responses) > 5:
        session.recent_ai_responses.pop(0)
            
    # 6. Send binary audio ONCE to frontend with playback gating
    if session.websocket and session.state not in (CallState.ENDED,):
        try:
            # Check if another playback is already in progress
            if session.is_ai_playing:
                logger.warning("[SCAMBAITER][%s][%s] PLAYBACK_BLOCKED: already playing audio", 
                             call_id, turn_id)
                return full_response_text
            
            # Mark playback as active
            session.is_ai_playing = True
            session.current_playback_turn_id = turn_id
            logger.info("[SCAMBAITER][%s] AI_PLAYBACK_GATE_ON", call_id)
            logger.info("[SCAMBAITER][%s][%s] PLAYBACK_START", call_id, turn_id)
            
            await session.websocket.send_bytes(audio_bytes)
            logger.info("[SCAMBAITER][%s][%s] AUDIO_SENT: %d bytes, voice_id=%s", 
                       call_id, turn_id, len(audio_bytes), session.user_voice_id)
            
            # Mark playback as complete after a short delay to ensure audio is fully sent
            await asyncio.sleep(0.1)  # Reduced from 500ms to 100ms for faster response
            session.is_ai_playing = False
            session.current_playback_turn_id = None
            logger.info("[SCAMBAITER][%s][%s] PLAYBACK_END", call_id, turn_id)
            logger.info("[SCAMBAITER][%s] AI_PLAYBACK_GATE_OFF", call_id)
            
        except Exception as exc:
            logger.error("[SCAMBAITER][%s][%s] AUDIO_SEND_FAILED: %s", call_id, turn_id, exc)
            session.is_ai_playing = False
            session.current_playback_turn_id = None
            return full_response_text
    else:
        logger.warning("[SCAMBAITER][%s][%s] NO_WEBSOCKET: cannot send audio", call_id, turn_id)
        return full_response_text
                
    # 7. Append the full response to history
    session.scambaiter_log.append({"role": "user", "content": caller_speech})
    session.scambaiter_log.append({"role": "assistant", "content": full_response_text.strip()})
    
    logger.info("[SCAMBAITER][%s][%s] TURN_COMPLETE: response=%r, voice_id=%s", 
               call_id, turn_id, full_response_text[:60], session.user_voice_id)
    
    return full_response_text


async def _scambaiter_loop(call_id: str) -> None:
    """
    Independent asyncio task: waits for transcribed caller speech,
    then executes the Scambaiter persona loop sequentially.
    
    HARD TURN LOCK: Only one turn processes at a time to prevent overlapping LLM/TTS calls.
    CONVERSATION MEMORY: Maintains recent utterances and responses for context-aware behavior.
    """
    session = manager.get_session(call_id)
    if not session:
        return

    logger.info("[SCAMBAITER][%s] LOOP_STARTED", call_id)
    logger.info("[SCAMBAITER][%s] SCAMBAITER_STATE=LISTENING", call_id)
    turn_counter = 0

    while session.state not in (CallState.ENDED,):
        try:
            try:
                # Use a timeout so we can periodically check session.state
                transcript_window = await asyncio.wait_for(session.scambaiter_queue.get(), timeout=1.0)
            except asyncio.TimeoutError:
                # Continue listening - no transcript this cycle
                continue

            # Increment turn counter
            turn_counter += 1
            turn_id = f"{call_id}_{turn_counter}"
            
            # Validate transcript before processing
            if not _is_valid_transcript(transcript_window):
                logger.warning("[SCAMBAITER][%s][TURN_%d] TRANSCRIPT_REJECTED: %r (too short/invalid)", 
                              call_id, turn_counter, transcript_window[:50])
                continue
            
            # Check for duplicate scammer utterance - SKIP PROCESSING if duplicate
            if _is_duplicate_utterance(transcript_window, session.recent_scammer_utterances):
                logger.warning("[SCAMBAITER][%s][TURN_%d] UTTERANCE_DUPLICATE_SKIPPED: %r (similar to recent)", 
                              call_id, turn_counter, transcript_window[:50])
                continue  # Skip processing duplicate utterances completely
            
            # AI PLAYBACK GATE: Do not process STT while AI is playing
            if session.is_ai_playing:
                logger.warning("[SCAMBAITER][%s][TURN_%d] AI_PLAYBACK_GATE_ON: dropping transcript during AI playback", 
                             call_id, turn_counter)
                continue
            
            # Add to conversation memory
            session.recent_scammer_utterances.append(transcript_window)
            if len(session.recent_scammer_utterances) > 5:
                session.recent_scammer_utterances.pop(0)
            
            # Acquire turn lock to prevent overlapping processing
            async with session.scambaiter_turn_lock:
                if session.is_processing_turn:
                    logger.warning("[SCAMBAITER][%s][TURN_%d] DUPLICATE_IGNORED: already processing turn", 
                                  call_id, turn_counter)
                    continue
                
                # Idempotency guard: reject if this turn was already processed
                if turn_id in session.processed_turn_ids:
                    logger.warning("[SCAMBAITER][%s][TURN_%d] DUPLICATE_TURN_DROPPED: turn_id already processed", 
                                 call_id, turn_counter)
                    continue
                
                session.processed_turn_ids.add(turn_id)
                session.is_processing_turn = True
                session.current_turn_id = turn_id
                
                logger.info("[SCAMBAITER][%s] SCAMBAITER_STATE old=LISTENING new=PROCESSING", call_id)
                logger.info("[SCAMBAITER][%s][TURN_%d] TURN_START: transcript=%r, context_size=%d", 
                           call_id, turn_counter, transcript_window[:80], len(session.scambaiter_log))
                
                try:
                    # Process the turn
                    ai_response = await _fire_scambaiter_turn(call_id, transcript_window, turn_id)
                    
                    if ai_response:
                        session.last_processed_turn_id = turn_id
                    
                    logger.info("[SCAMBAITER][%s][TURN_%d] TURN_COMPLETE", call_id, turn_counter)
                    logger.info("[SCAMBAITER][%s] SCAMBAITER_STATE old=PROCESSING new=LISTENING", call_id)
                    logger.info("[SCAMBAITER][%s] SCAMBAITER_LISTENING_READY", call_id)
                finally:
                    session.is_processing_turn = False
                    session.current_turn_id = None

        except asyncio.CancelledError:
            logger.info("[SCAMBAITER][%s] LOOP_CANCELLED", call_id)
            logger.info("[SCAMBAITER][%s] SCAMBAITER_LOOP_EXIT reason=CANCELLED", call_id)
            break
        except Exception as exc:
            logger.error("[SCAMBAITER][%s] LOOP_ERROR: %s", call_id, exc)
            logger.info("[SCAMBAITER][%s] SCAMBAITER_LOOP_EXIT reason=ERROR error=%s", call_id, str(exc))
            session.is_processing_turn = False
            await asyncio.sleep(1.0)
    
    # Log when loop exits naturally (call ended)
    logger.info("[SCAMBAITER][%s] SCAMBAITER_LOOP_EXIT reason=CALL_ENDED", call_id)


# ── STT + Fact-Check loop ──────────────────────────────────────────────────────

async def _stt_loop(call_id: str) -> None:
    """
    Independent asyncio task: accumulates audio into utterance chunks,
    runs Whisper STT, then feeds into claim extraction → search → verdict.

    Latency: 1.5–4s end-to-end (see §1.5). Never blocks DSP loops.
    The UI shows "verifying…" (factcheck_update with status="VERIFYING") until done.

    Video evidence capture is handled by the dedicated _evidence_capture_loop
    task (200 ms cadence) — NOT here — so frame commits are never gated on
    STT pipeline latency.
    """
    cfg = get_settings()
    session = manager.get_session(call_id)
    if not session:
        return

    buf = session.buffer
    stt_acc = STTAccumulator(fs=cfg.sample_rate)
    claim_extractor = ClaimExtractor(debounce_chars=200)
    search_verifier = SearchVerifier()

    # Read chunk size: 0.5s at a time for the accumulator
    read_n = cfg.sample_rate // 2

    # Track language for adaptive prompting
    # Start with None (auto-detect) - do NOT assume Hindi for India market
    # Let Whisper auto-detect from actual audio
    detected_lang_hint: str | None = None
    full_transcript = ""

    logger.debug("stt_loop started: call_id=%r", call_id)
    logger.info("[STT][%s] REMOTE_AUDIO_CAPTURE_START", call_id)

    while session.state not in (CallState.ENDED,):
        try:
            chunk = buf.get_window("stt", read_n)
            if chunk is None:
                await asyncio.sleep(0.5)
                continue

            stt_acc.add(chunk)
            logger.info("[STT][%s] REMOTE_AUDIO_FRAME_RECEIVED", call_id)

            # AI PLAYBACK GATE: Skip STT processing while AI is playing
            if session.is_ai_playing:
                logger.info("[STT][%s] AI_PLAYBACK_GATE_ON: skipping audio during AI playback", call_id)
                logger.info("[STT][%s] AI_AUDIO_CAPTURE_DROPPED: reason=AI_PLAYBACK", call_id)
                # Reset accumulator to drop buffered AI audio
                stt_acc = STTAccumulator(fs=16000)
                await asyncio.sleep(0.1)
                continue

            if not stt_acc.ready():
                await asyncio.sleep(0.1)
                continue

            audio_chunk = stt_acc.get_chunk()
            if audio_chunk is None:
                continue

            # Language detection for adaptive prompting
            # Only update language hint after we have enough transcript and with stability
            if len(full_transcript) > 50:
                lang_result = detect_language(full_transcript[-200:])
                candidate_lang = lang_result["stt_language_hint"]
                confidence = lang_result.get("confidence", 0.0)
                support_level = lang_result.get("support_level", "UNVERIFIED")
                is_code_switched = lang_result.get("is_code_switched", False)
                
                # Language stability: only switch if we have consistent evidence
                # Prevent flipping between languages on single chunk anomalies
                if candidate_lang != session.detected_language:
                    session.language_evidence_count += 1
                    # Require 3 consistent chunks OR high confidence before switching language
                    if session.language_evidence_count >= 3 or confidence > 0.7:
                        session.detected_language = candidate_lang
                        session.language_confidence = confidence
                        session.is_code_switched = is_code_switched
                        session.support_level = support_level
                        session.primary_language = lang_result.get("primary_language")
                        session.secondary_languages = lang_result.get("secondary_languages", [])
                        session.language_evidence_count = 0
                        detected_lang_hint = candidate_lang
                        logger.info(
                            "Language stabilized to %s (confidence=%.2f, support=%s, code_switched=%s) for call_id=%r",
                            candidate_lang, confidence, support_level, is_code_switched, call_id
                        )
                else:
                    # Language already stable, keep using it
                    session.language_evidence_count = 0
                    detected_lang_hint = session.detected_language

            # Signal "verifying" to client
            await manager.send_json(call_id, {
                "type": "factcheck_update",
                "status": "VERIFYING",
                "message": "Analyzing caller claims…",
                "evidence_urls": [],
                "ts": _ts(),
            })

            # STT transcription (non-blocking, runs in executor via Groq async client)
            transcript = await transcribe_chunk(
                audio_chunk,
                fs=cfg.sample_rate,
                language=detected_lang_hint,
                call_id=call_id,
            )

            if not transcript:
                continue

            full_transcript += " " + transcript
            session.transcript_history.append(transcript)

            # Broadcast transcript chunk to frontend for live display
            await manager.send_json(call_id, {
                "type": "transcript_update",
                "text": transcript,
                "is_final": True,
                "language": session.detected_language,
                "language_confidence": session.language_confidence,
                "is_code_switched": session.is_code_switched,
                "support_level": session.support_level,
                "primary_language": session.primary_language,
                "secondary_languages": session.secondary_languages,
                "ts": _ts(),
            })

            if session.state == CallState.SCAMBAITER_ACTIVE:
                # Bypass fact-checking and queue the transcript directly for the scambaiter loop
                # We do this immediately instead of waiting for claim_extractor to accumulate 50 chars
                try:
                    session.scambaiter_queue.put_nowait(transcript)
                    logger.info("[STT][%s] TRANSCRIPT_QUEUED_FOR_SCAMBAITER: %r", call_id, transcript[:50])
                except asyncio.QueueFull:
                    logger.warning("[STT][%s] TRANSCRIPT_DROPPED_QUEUE_FULL: scambaiter loop too slow", call_id)
                # Continue to next audio chunk - DO NOT break the loop
                continue

            # --- LOCAL LLM TRAPDOOR (Layers 1 & 2) ---
            from factcheck.local_llm import LocalScamClassifier
            local_classifier = LocalScamClassifier()
            if local_classifier.is_loaded:
                local_prediction = await local_classifier.predict_instant_scam(transcript)
                if local_prediction and local_prediction.get("is_confident"):
                    is_scam = local_prediction.get("is_scam")
                    status = "CRITICAL" if is_scam else "SAFE"
                    prefix = "⚠️ INSTANT ALERT" if is_scam else "✅ INSTANT SAFE"
                    
                    logger.info(f"[LOCAL LLM] {status} Detected: {local_prediction.get('category')}")
                    
                    verdict_entry = {
                        "status": status,
                        "message": f"{prefix} (Local AI): " + local_prediction.get("reasoning", ""),
                        "evidence_urls": [],
                        "category": local_prediction.get("category", "UNKNOWN"),
                        "ts": _ts(),
                    }
                    session.factcheck_history.append(verdict_entry)
                    await manager.send_json(call_id, {
                        "type": "factcheck_update",
                        **verdict_entry,
                    })
                    
                    # Bypass Layer 3 fact-checking
                    continue
            # ---------------------------------------

            # Accumulate in claim extractor (debounced)
            claim_extractor.add_transcript(transcript)

            if not claim_extractor.ready():
                continue

            transcript_window = claim_extractor.get_and_reset()

            # Claim extraction + search + verdict (1.5–4s pipeline)
            claim = await claim_extractor.extract(transcript_window, full_transcript=full_transcript, call_id=call_id)
            search_result = None
            if claim:
                search_result = await search_verifier.verify_claim(claim, call_id=call_id)

            verdict = await generate_verdict(
                transcript=transcript_window,
                claim=claim,
                search_result=search_result,
                call_id=call_id,
            )

            # Store verdict history
            verdict_entry = {
                "status": verdict["status"],
                "message": verdict["message"],
                "evidence_urls": verdict["evidence_urls"],
                "category": verdict.get("category", "UNKNOWN"),
                "ts": _ts(),
            }
            session.factcheck_history.append(verdict_entry)

            # Broadcast to client
            await manager.send_json(call_id, {
                "type": "factcheck_update",
                **verdict_entry,
            })

            # Auto-trigger family SMS on CRITICAL (notifier will check state)
            if verdict["status"] == "CRITICAL":
                if cfg.family_contact_number:
                    from escalation.notifier import send_family_alert
                    asyncio.create_task(
                        send_family_alert(
                            destination_number=cfg.family_contact_number,
                            call_id=call_id,
                            verdict=verdict["status"],
                            message=verdict["message"],
                        )
                    )
                               
        except asyncio.CancelledError:
            logger.debug("stt_loop cancelled: call_id=%r", call_id)
            logger.info("[STT][%s] REMOTE_AUDIO_CAPTURE_STOP", call_id)
            break
        except (httpx.ConnectError, httpx.ReadTimeout, httpx.ConnectTimeout) as exc:
            logger.warning("Network failure in STT loop [%s]: %s. Falling back to LIMITED mode.", call_id, exc)
            if session.mode != "limited":
                session.mode = "limited"
                await manager.send_json(call_id, {
                    "type": "mode_update",
                    "mode": "limited",
                    "ts": _ts()
                })
                # Send UNCERTAIN for current claim
                await manager.send_json(call_id, {
                    "type": "factcheck_update",
                    "status": "UNCERTAIN",
                    "message": "Network unavailable. Fact-checker is offline. Relying on local DSP.",
                    "evidence_urls": [],
                    "category": "UNKNOWN",
                    "ts": _ts()
                })
                
            await asyncio.sleep(2.0)
        except Exception as exc:
            logger.error("stt_loop error [%s]: %s", call_id, exc)
            logger.info("[STT][%s] REMOTE_AUDIO_CAPTURE_STOP", call_id)
            await asyncio.sleep(1.0)


# ── Main WebSocket endpoint ────────────────────────────────────────────────────

@router.websocket("/ws/call/{call_id}")
async def call_websocket(websocket: WebSocket, call_id: str) -> None:
    """
    Main WebSocket endpoint for live call audio analysis.

    Client connects with: ws://host/ws/call/{call_id}?token=<jwt>

    Accepts binary frames (PCM16LE, 20-50ms chunks).
    Sends JSON analysis updates.
    """
    # JWT validation before accepting — rejects invalid/expired tokens
    try:
        await verify_ws_token(websocket, call_id)
    except Exception:
        # verify_ws_token already called websocket.close()
        return

    await websocket.accept()

    # Get or create session
    session = manager.get_session(call_id)
    if session is None:
        logger.warning("WS connect for unknown call_id=%r — creating new session", call_id)
        session = manager.create_session(call_id)

    await manager.connect(call_id, websocket)
    ingestion = BrowserMicIngestion(call_id, session.buffer)

    cfg = get_settings()

    # Notify client of successful connection
    await manager.send_json(call_id, {
        "type": "connected",
        "call_id": call_id,
        "ts": _ts(),
    })

    # Send configuration information
    await manager.send_json(call_id, {
        "type": "config_info",
        "dsp_enabled": cfg.dsp_voice_detection_enabled,
        "ts": _ts(),
    })

    # Perform and broadcast Number Intel if caller_number is provided
    if session.caller_number:
        voip_info = detect_voip_pattern(session.caller_number)
        rep = get_reputation(session.caller_number)
        await manager.send_json(call_id, {
            "type": "number_intel",
            "is_likely_voip": voip_info["is_likely_voip"],
            "voip_confidence": voip_info["confidence"],
            "times_reported": rep.get("times_reported", 0),
            "registration_circle": "Delhi NCR" if session.caller_number.startswith("9198") else "Unknown",
            "ts": _ts(),
        })

    # ── PRIMARY: STT / Fact-Check loop — ALWAYS runs ──────────────────────────
    stt_task = asyncio.create_task(_stt_loop(call_id))
    session.stt_task = stt_task

    # ── SCAMBAITER: Dedicated audio loop ──────────────────────────────────────
    scambaiter_task = asyncio.create_task(_scambaiter_loop(call_id))
    session.scambaiter_task = scambaiter_task

    # ── ALWAYS: Video evidence capture loop — runs at 200ms cadence ───────────
    # Decoupled from STT so frames are committed to permanent record within
    # 200ms of a CRITICAL verdict, regardless of STT pipeline latency.
    evidence_task = asyncio.create_task(_evidence_capture_loop(call_id))
    session.evidence_task = evidence_task  # type: ignore[attr-defined]

    # ── EXPERIMENTAL: DSP loops — only when flag is on ────────────────────────
    bispectrum_task = None
    tremor_task = None
    if cfg.dsp_voice_detection_enabled:
        bispectrum_task = asyncio.create_task(_bispectrum_loop(call_id))
        tremor_task = asyncio.create_task(_tremor_loop(call_id))
        session.bispectrum_task = bispectrum_task
        session.tremor_task = tremor_task
        logger.info("DSP loops ENABLED for call_id=%r", call_id)
    else:
        logger.info("DSP loops DISABLED for call_id=%r (DSP_VOICE_DETECTION_ENABLED=false)", call_id)

    # ── HF ML loop — only when token is present ───────────────────────────────
    hf_task = None
    if cfg.hf_api_token:
        hf_task = asyncio.create_task(_hf_ml_loop(call_id))
        session.hf_task = hf_task  # type: ignore[attr-defined]
        logger.info("HF ML loop ENABLED for call_id=%r", call_id)

    try:
        while True:
            # Idle timeout: terminate connection if no audio received for 300 seconds
            try:
                raw_message = await asyncio.wait_for(websocket.receive(), timeout=300.0)
            except asyncio.TimeoutError:
                logger.warning("WebSocket idle timeout: call_id=%r", call_id)
                break

            # ── Handle JSON control messages (text frames) ────────────────────
            if "text" in raw_message:
                try:
                    import json as _json
                    ctrl = _json.loads(raw_message["text"])
                    msg_type = ctrl.get("type", "")

                    if msg_type == "ping":
                        # Keepalive ping from Flutter client — pong back
                        try:
                            await manager.send_json(call_id, {"type": "pong", "ts": _ts()})
                        except Exception:
                            pass
                        continue

                    elif msg_type == "set_voice_id":
                        # Flutter enrolled user voice → store voice_id for TTS cloning
                        voice_id = ctrl.get("voice_id", "")
                        if voice_id:
                            session.user_voice_id = voice_id
                            logger.info(
                                "Voice clone: voice_id=%r stored for call_id=%r",
                                voice_id, call_id,
                            )
                        continue

                    elif msg_type == "transcript_analysis_request":
                        # Level 3 text analysis request from Flutter
                        text = ctrl.get("text", "")
                        if text and session.state == CallState.SCAMBAITER_ACTIVE:
                            session.scambaiter_queue.put_nowait(text)
                        continue

                    else:
                        logger.debug("Unhandled JSON message type=%r for call_id=%r", msg_type, call_id)
                        continue
                except Exception as json_exc:
                    logger.warning("Malformed JSON control message (call_id=%r): %s", call_id, json_exc)
                    continue

            # ── Handle binary audio frames ────────────────────────────────────
            message = raw_message.get("bytes")
            if not message:
                continue

            # Payload validation: limit frame size to prevent memory abuse (max 64KB)
            if len(message) > 65536:
                logger.error("WebSocket abuse detected: frame size %d > 64KB, call_id=%r", len(message), call_id)
                break

            # Ingest binary audio frame safely
            try:
                n = ingestion.ingest_frame(message)
                # Accumulate raw bytes for forensic hash
                session.recorded_audio_bytes += message
                logger.debug("Audio frame: %d bytes → %d samples (call_id=%r)", len(message), n, call_id)
            except Exception as frame_exc:
                logger.error("Malformed audio frame dropped (call_id=%r): %s", call_id, frame_exc)
                continue

    except WebSocketDisconnect:
        logger.info("WebSocket disconnected: call_id=%r", call_id)
    except Exception as exc:
        logger.error("WebSocket error [%s]: %s", call_id, exc)
        try:
            await manager.send_json(call_id, {"type": "error", "message": str(exc), "ts": _ts()})
        except Exception:
            pass
    finally:
        await manager.disconnect(call_id)
        logger.info("Call session cleanup complete: call_id=%r", call_id)
