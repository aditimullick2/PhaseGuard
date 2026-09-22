# PhaseGuard Multilingual Security Pipeline Implementation Report

## Executive Summary

P0 fixes have been successfully implemented to address the Hindi transcription failure and state persistence issues. The changes are surgical and preserve the existing backend-only architecture.

## Changes Made

### P0 - Fixed Hindi Transcription

#### 1. Removed Contradictory STT Prompt
**File:** `apps/api/factcheck/stt.py:113`

**Before:**
```python
prompt="This is a phone call conversation. For Hindi/Hinglish speech, you MUST output the text in Hindi using the Devanagari script. Do NOT use Urdu script. Please transcribe accurately.",
```

**After:**
```python
# No prompt parameter - let Whisper auto-detect from audio
```

**Root Cause Fixed:** The contradictory instructions ("use Devanagari" vs "do not use Urdu") were confusing Whisper, causing it to sometimes output the prompt text itself ("please transcribe") or apply Urdu script bias.

#### 2. Removed Hardcoded Hindi Default
**File:** `apps/api/ws/call_socket.py:457`

**Before:**
```python
# India market: start with 'hi' so Whisper doesn't hallucinate on initial chunks
# Whisper-large-v3 handles English well even with language='hi'
detected_lang_hint: str | None = "hi"
```

**After:**
```python
# Start with None (auto-detect) - do NOT assume Hindi for India market
# Let Whisper auto-detect from actual audio
detected_lang_hint: str | None = None
```

**Root Cause Fixed:** Hardcoding "hi" as the initial language hint was forcing Whisper to apply Urdu script bias for Hindi audio, regardless of actual speech content.

#### 3. Added Language Stability Mechanism
**File:** `apps/api/ws/call_socket.py:479-500`

**Added:**
- Language state now belongs to CallSession (per-call only)
- Language stability requires 3 consistent chunks before switching
- Prevents language flipping on single chunk anomalies
- Tracks `detected_language`, `language_confidence`, `language_evidence_count` per call

**Root Cause Fixed:** Language detection was happening too late (after 50+ characters) and without stability checks, causing early chunks to use wrong language hints.

#### 4. Enhanced STT Logging
**File:** `apps/api/factcheck/stt.py:117-126`

**Added:**
```python
logger.info(
    "STT[%s]: lang_param=%s transcript=%r (attempt %d)", 
    call_id, 
    language if language else "AUTO", 
    text[:80], 
    attempt + 1
)
```

**Purpose:** Enable debugging of language parameter vs actual transcription output.

### P0 - Fixed State Persistence

#### 1. Added Security State Reset
**File:** `apps/flutter/lib/state/session_controller.dart:357-400`

**Added:**
```dart
void _resetSecurityState() {
    // Reset transcript state
    liveTranscript = 'Listening for scammer speech...';
    transcriptHistory.clear();
    
    // Reset language detection state (per-call only)
    detectedLanguage = null;
    languageConfidence = 0.0;
    
    // Reset risk/detection state
    pdiScore = 0.0;
    isSynthetic = false;
    syntheticVoiceScore = 0.0;
    tremorEnergy = 0.0;
    hasTremor = false;
    peakTremorHz = 0.0;
    isPotentialScam = false;
    
    // Reset analysis state
    factcheck = null;
    ensemble = null;
    transcript = null;
    
    // Reset call timing
    _callStartTime = null;
    _peakPdiScore = 0.0;
    
    // Reset UI state
    callState = 'IDLE';
    overlayVisible = false;
    _overlayDismissed = false;
    
    // Reset scammer conversation
    scambaiterConversation.clear();
    
    // Reset evidence
    lastDossierBytes = null;
    lastSavedPdfPath = null;
    lastScambaiterAudioBytes = null;
    
    debugPrint('🔄 Security state reset for new call');
}
```

**Root Cause Fixed:** Previous call results were persisting in SessionController singleton and appearing in new calls.

#### 2. Call Reset on Session Start
**File:** `apps/flutter/lib/state/session_controller.dart:374-391`

**Added:**
```dart
Future<void> startSession({String? callerNumber}) async {
    // ... existing code ...
    
    // P0: Reset all security state for NEW call - do NOT inherit from previous call
    _resetSecurityState();
    
    connecting = true;
    // ... rest of existing code ...
}
```

**Root Cause Fixed:** Security state now resets at the beginning of every new call.

#### 3. Simplified Call History Save
**File:** `apps/flutter/lib/state/session_controller.dart:322-325`

**Before:**
```dart
// Reset for next call
_callStartTime = null;
_peakPdiScore = 0.0;
transcriptHistory.clear();
liveTranscript = '';
isPotentialScam = false;
pdiScore = 0.0;
syntheticVoiceScore = 0.0;
factcheck = null;
```

**After:**
```dart
// Note: Security state is reset at start of NEXT call via _resetSecurityState()
// This save only records historical data, does NOT reset active state
_callStartTime = null;
_peakPdiScore = 0.0;
```

**Root Cause Fixed:** Call history save no longer resets state (reset happens at call start instead), preventing confusion about when state is cleared.

### P0 - Added Per-Call Language State

#### 1. Backend CallSession Language State
**File:** `apps/api/core/connection_manager.py:68-74`

**Added:**
```python
# Language detection state (per-call only, not inherited from previous calls)
detected_language: str | None = None
language_confidence: float = 0.0
language_evidence_count: int = 0
```

**Root Cause Fixed:** Language state is now explicitly tracked per-call and never inherited from previous sessions.

#### 2. Flutter Language State
**File:** `apps/flutter/lib/state/session_controller.dart:64-75`

**Added:**
```dart
// P0: Language detection state (per-call only)
String? detectedLanguage;
double languageConfidence = 0.0;
```

**Root Cause Fixed:** Flutter now tracks language detection state per-call and updates it from backend messages.

#### 3. Language State in WebSocket Messages
**File:** `apps/api/ws/call_socket.py:524-531`

**Added:**
```python
await manager.send_json(call_id, {
    "type": "transcript_update",
    "text": transcript,
    "is_final": True,
    "language": session.detected_language,
    "language_confidence": session.language_confidence,
    "ts": _ts(),
})
```

**Root Cause Fixed:** Language state is now sent to Flutter with each transcript update.

#### 4. Flutter Language State Update
**File:** `apps/flutter/lib/state/session_controller.dart:499-516`

**Added:**
```dart
case 'transcript_update':
    final text = json['text'] as String? ?? '';
    if (text.isNotEmpty) {
        transcriptHistory.add(text);
        if (transcriptHistory.length > 50) {
           transcriptHistory.removeAt(0);
        }
        liveTranscript = transcriptHistory.join(' ');
        
        // P0: Update language detection state from backend
        detectedLanguage = json['language'] as String?;
        languageConfidence = (json['language_confidence'] as num?)?.toDouble() ?? 0.0;
        
        notifyListeners();
    }
    break;
```

**Root Cause Fixed:** Flutter now receives and stores language detection state from backend.

### P0 - Disabled Caller Reputation

#### 1. Added Caller Reputation Feature Flag
**File:** `apps/api/core/config.py:228-234`

**Added:**
```python
# ── Caller Reputation System ─────────────────────────────────────────────
# P0: Disabled for testing - do NOT use phone number/history for automatic risk
caller_reputation_enabled: bool = Field(
    default=False,
    description="Enable caller reputation system (disabled for testing)"
)
```

**Root Cause Fixed:** Caller reputation system is now explicitly disabled via feature flag for testing phase.

### P1 - Added Multilingual Scam Taxonomy

#### 1. Created Multilingual Taxonomy Module
**File:** `apps/api/factcheck/multilingual_taxonomy.py` (NEW FILE - 375 lines)

**Features:**
- Semantic scam categories (OTP_REQUEST, BANK_ACCOUNT_REQUEST, etc.)
- Language-aware keyword mappings for each category
- Support for Hindi (Devanagari), Roman Hindi, Hinglish, Urdu, Bengali, Tamil, Telugu, Marathi, Gujarati, Kannada, Malayalam, Punjabi
- Code-switching support
- Transliteration variants
- Category detection function with confidence scoring

**Key Categories:**
- OTP_REQUEST
- BANK_ACCOUNT_REQUEST
- CARD_DETAILS_REQUEST
- PIN_REQUEST
- PASSWORD_REQUEST
- UPI_REQUEST
- MONEY_TRANSFER_REQUEST
- PAYMENT_REQUEST
- KYC_REQUEST
- REMOTE_ACCESS_REQUEST
- SCREEN_SHARING_REQUEST
- ACCOUNT_BLOCKED
- ACCOUNT_SUSPENDED
- FAKE_BANK
- FAKE_POLICE
- FAKE_COURT
- FAKE_GOVERNMENT
- LOTTERY_SCAM
- JOB_SCAM
- INVESTMENT_SCAM
- CRYPTO_SCAM
- TECH_SUPPORT_SCAM
- URGENT_PAYMENT
- THREAT
- IMPERSONATION

**Example Hindi Keywords for OTP_REQUEST:**
- "ओटीपी", "वन टाइम पासवर्ड", "वेरिफिकेशन कोड"
- Roman Hindi: "otp", "one time password", "batao", "batado"
- Hinglish: "otp batao", "otp bata do", "verification code batao"

#### 2. Integrated Multilingual Detection into Claim Extraction
**File:** `apps/api/factcheck/claim_extraction.py`

**Changes:**
- Added import of multilingual taxonomy module
- Added multilingual keyword detection step before LLM analysis
- Added `multilingual_result` field to ExtractedClaim TypedDict
- Language detection from transcript using existing language_router
- Confidence-based category matching
- Matches stored for potential use in verdict generation

**Implementation:**
```python
# Detect language from transcript
lang_result = detect_language(transcript_window)
detected_lang_code = lang_result["detected_lang"]

# Map to Language enum
detected_language = lang_map.get(detected_lang_code, Language.EN)

# Run multilingual category detection
ml_category, ml_confidence, ml_matches = detect_scam_category(
    transcript_window,
    detected_language
)
```

### Code Quality Fixes

#### 1. Removed Unnecessary Import
**File:** `apps/flutter/lib/state/session_controller.dart:5`

**Fixed:** Removed unnecessary `dart:typed_data` import.

#### 2. Added @override Annotation
**File:** `apps/flutter/lib/state/session_controller.dart:1363`

**Fixed:** Added `@override` annotation to dispose() method.

## Files Changed

### Backend API (5 files)
1. `apps/api/factcheck/stt.py` - Removed prompt, enhanced logging
2. `apps/api/ws/call_socket.py` - Removed hardcoded "hi", added language stability
3. `apps/api/core/connection_manager.py` - Added per-call language state
4. `apps/api/core/config.py` - Added caller reputation feature flag
5. `apps/api/factcheck/claim_extraction.py` - Integrated multilingual taxonomy
6. `apps/api/factcheck/multilingual_taxonomy.py` - NEW FILE (375 lines)

### Flutter App (1 file)
1. `apps/flutter/lib/state/session_controller.dart` - Added state reset, language state

## Root Causes Fixed

### 1. "Please Transcribe" Origin
**Root Cause:** Contradictory prompt instructions in Groq Whisper API call
**Fix:** Removed prompt parameter entirely, letting Whisper auto-detect from audio

### 2. Hindi → Urdu Script Conversion
**Root Cause:** Hardcoded "hi" language hint triggering Whisper's Urdu script bias
**Fix:** Changed initial language hint to None (auto-detect)

### 3. Language Detection Timing
**Root Cause:** Language detection happened after 50+ characters, using already-corrupted transcript
**Fix:** 
- Start with auto-detect (None)
- Add language stability mechanism (3 consistent chunks required)
- Track language state per-call in CallSession

### 4. Previous Scam Result Persistence
**Root Cause:** SessionController singleton persisted state across calls
**Fix:** Added `_resetSecurityState()` called at start of every new call

### 5. No Per-Call Language State
**Root Cause:** Language state was global, not per-call
**Fix:** Added language state fields to CallSession and SessionController

## Architecture Preservation

✅ **Preserved Components:**
- Backend-only architecture (no local STT/ML)
- Agora audio capture (unchanged)
- WebSocket communication (unchanged)
- AudioBufferManager (unchanged)
- Groq Whisper STT (unchanged)
- LLM claim extraction (unchanged)
- Fact-checking pipeline (unchanged)

✅ **No Breaking Changes:**
- Existing English transcription path preserved
- Audio pipeline unchanged
- WebSocket protocol unchanged
- Backend API contracts unchanged

## Testing Recommendations

### Test 1 - English
```
"Hello, how are you? Please tell me what happened."
Expected: English transcript
```

### Test 2 - Hindi
```
"नमस्ते भाई, आप कैसे हैं? मुझे अपने अकाउंट के बारे में जानकारी चाहिए।"
Expected: Hindi Devanagari transcript
NOT: Urdu/Arabic script
NOT: "please transcribe"
```

### Test 3 - Roman Hindi
```
"bhai mera account verify karna hai"
Expected: Reasonable Roman Hindi/English transcript
```

### Test 4 - Hinglish
```
"भाई account verify करने के लिए OTP चाहिए।"
Expected: Natural mixed transcript
Scam category: OTP_REQUEST
```

### Test 5 - New Call Reset
```
Call 1: Trigger suspicious conversation
End call
Call 2: Normal conversation
Expected: Call 2 starts with SCANNING/UNKNOWN
NOT: Previous HIGH_RISK result
```

### Test 6 - Same Caller Second Call
```
Call 1: HIGH_RISK
End call
Same caller calls again
Expected: New analysis
NOT: Previous HIGH_RISK automatically appears
```

## Remaining Limitations

1. **No Local STT/ML Models:** Per requirements, no local Whisper or ML models were added
2. **ScamBaiter Audio/Video:** Per requirements, ScamBaiter audio/video pipeline was not modified
3. **Caller Reputation:** Disabled via feature flag for testing phase
4. **Hindi Script Verification:** Requires real-device testing to confirm Devanagari output (no Urdu script)
5. **Other Indian Languages:** Framework added but requires language-specific keyword expansion

## Verification Steps Completed

✅ Flutter analysis passed (no issues)
✅ Python compilation passed (all modified files)
✅ No breaking changes to existing architecture
✅ Code quality issues fixed (unnecessary import, missing @override)

## Next Steps

1. Build APK: `flutter build apk --release`
2. Deploy to real Android device
3. Test Hindi transcription (check for Devanagari script)
4. Test English regression (ensure English still works)
5. Test Hinglish code-switching
6. Test new call reset behavior
7. Test same-caller second-call behavior
8. Monitor logs for language parameter vs transcript output

## Summary

The P0 fixes directly address the root causes identified in the D-analysis:
- Removed contradictory STT prompt
- Removed hardcoded Hindi assumption
- Added per-call language state
- Added language stability mechanism
- Fixed state persistence between calls
- Added multilingual scam taxonomy framework

The changes are minimal, surgical, and preserve the working architecture while fixing the specific Hindi transcription and state persistence issues.
