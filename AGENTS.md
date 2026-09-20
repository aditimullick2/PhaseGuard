# PhaseGuard Architecture & Development Guide

## 🏗️ System Architecture

### 3-Level Detection Architecture

**Core Philosophy:** Local-first, API-efficient, offline-capable protection

```
LEVEL 1 (Local Scam Text) → LEVEL 2 (Local Deepfake) → LEVEL 3 (Web Backend)
        ↓                            ↓                         ↓
   Keyword + ML                 TFLite CNN + DSP          Full AI Pipeline
   Confidence Check            PARALLEL (Local+Web)      Fact-Check/Advanced
        ↓                            ↓                         ↓
   If CONFIDENT                 Jo pehle aaye              If UNCERTAIN
   STOP (API SAVED)            use karo                  Escalate from L1/L2
   OR FACT-CHECK               Web = FINAL               OR FACT-CHECK
   → Go to Web                 (best model)              (company/scheme)
```

### LEVEL 1: Local Scam Text Detection
- **Location:** `apps/flutter/lib/services/scam_detector_service.dart`
- **Method:** 300+ scam keywords + TFLite neural network
- **Accuracy:** 98.7% (keywords), 85%+ (ML model)
- **Offline:** ✅ Works offline, escalates to web when uncertain/fact-checking needed
- **Controller:** `SessionController._runLevel1ScamTextAnalysis()`
- **Web Escalation:** When uncertain (30-70% confidence) or fact-checking triggers detected

### LEVEL 2: Local Deepfake Detection
- **Location:** `apps/flutter/lib/services/deepfake_detector_service.dart`
- **Method:** TFLite CNN model + DSP heuristics (PARALLEL with web multi-detector)
- **Accuracy:** 75% on user voices (local), higher with web
- **Offline:** ✅ Works offline, parallel web when available
- **Controller:** `SessionController._runLevel2DeepfakeAnalysis()`
- **Parallel Processing:** Local + Web run simultaneously, jo pehle aaye use karo, web result = FINAL (best model)

### LEVEL 3: Web Backend
- **Location:** `apps/api/`
- **Method:** Groq LLM + web search + multi-detector deepfake
- **Purpose:** Fact-checking, advanced analysis
- **Controller:** `SessionController._escalateToWebTextAnalysis()`, `_escalateToWebAudioAnalysis()`

## 🔊 Audio Capture Architecture

### Agora AudioFrameObserver (No Speakerphone Required)
- **Location:** `apps/flutter/lib/services/agora_calling_service.dart`
- **Method:** `AudioFrameObserver.onPlaybackAudioFrameBeforeMixing`
- **Format:** 16kHz mono PCM
- **Capture:** SDK-level (independent of speakerphone)
- **Source:** REMOTE caller audio (not local microphone)

### Audio Flow
```
Scammer's Voice → Phone Network → Android Audio → Agora SDK → AudioFrameObserver
    ↓
16kHz PCM Chunks (100ms intervals, 3200 bytes)
    ↓
LEVEL 2 (Local Deepfake) Processing
    ↓
LEVEL 3 (Web) Streaming (only if uncertain)
```

### Scambaiter Audio Delivery
- **Method:** Agora `playEffect(publish: true)`
- **Format:** PCM → WAV conversion
- **Target:** Remote scammer/caller
- **Real-time:** <500ms end-to-end latency

## 🎯 Real-Time Parallel Execution

### LEVEL 1 + LEVEL 2 Parallel Processing
- **Execution:** LEVEL 1 (Scam Text) and LEVEL 2 (Deepfake) run simultaneously via SessionController
- **Independence:** Both levels process independently - LEVEL 1 uses transcript, LEVEL 2 uses audio
- **Real-time:** Audio chunks (100ms) trigger LEVEL 2, WebSocket messages trigger LEVEL 1
- **Separate Services:** `ScamDetectorService` (local) and `DeepfakeDetectorService` (parallel local+web)

### LEVEL 2 Parallel Processing (Local + Web)
- **Service:** `DeepfakeDetectorService.analyze()` runs both local and web in parallel
- **Method:** `Future.any([localFuture, webFuture])` - jo pehle aaye use karo
- **Priority:** Web result = FINAL (best model)
- **Fallback:** If web fails/times out, local result is used
- **Benefits:** Fast local response (~200ms) + accurate web result (~1-4s) when available

### LEVEL 1 Web Escalation
- **Service:** `ScamDetectorService` processes locally (keyword + ML)
- **Escalation:** SessionController escalates to web when:
  - Local uncertain (30-70% confidence)
  - Fact-checking triggers detected (company names, schemes, government references)
- **Method:** WebSocket JSON request to backend for LLM + fact-checking
- **Benefits:** Fast local processing + authoritative web fact-checking when needed

## 🎯 API Saving Strategy

### Web Backend Called When:
1. **LEVEL 1 Uncertain:** Confidence 30-70% (escalate from SessionController)
2. **LEVEL 1 Fact-Check:** Company names, schemes, government references detected
3. **LEVEL 2 Local Uncertain:** Confidence 35-65% (escalate from SessionController if parallel service returned local)
4. **Advanced Verification:** Complex patterns requiring full AI pipeline

### Web Backend NOT Called When:
1. **LEVEL 1 Confident SCAM:** >70% confidence (API SAVED)
2. **LEVEL 1 Confident SAFE:** <30% confidence (API SAVED)
3. **LEVEL 2 Confident SYNTHETIC:** >65% confidence (API SAVED)
4. **LEVEL 2 Confident NATURAL:** <35% confidence (API SAVED)
5. **No Internet:** Offline mode active

### Fact-Check Keywords
```dart
const factCheckKeywords = [
  'company', 'scheme', 'pradhan mantri', 'pm', 'modi', 'lic', 'sbi',
  'bank', 'insurance', 'mutual fund', 'sip', 'fd', 'rd', 'rbi', 'sebi',
  'government', 'police', 'court', 'income tax', 'pan card', 'aadhar'
];
```

## 📱 Offline Mode

### Offline Capabilities
- ✅ LEVEL 1: Full scam text detection (keyword + ML) - local processing works offline
- ✅ LEVEL 2: Full deepfake detection (TFLite CNN + DSP) - local processing works offline
- ✅ LEVEL 2: Parallel web processing - works when internet available
- ✅ Real-time alerts
- ✅ Audio capture (Agora AudioFrameObserver)
- ✅ Web escalation skipped when offline
- ✅ 100% protection without internet (local levels only)

### Offline Mode Detection
- **Service:** `ConnectivityMonitor`
- **Location:** `apps/flutter/lib/services/connectivity_monitor.dart`
- **Transition:** Automatic offline/online mode switching
- **Fallback:** Local levels continue working

## 🔧 Key Files

### Flutter App
- `apps/flutter/lib/state/session_controller.dart` - Main state management, 3-level architecture
- `apps/flutter/lib/services/scam_detector_service.dart` - LEVEL 1: Scam text detection
- `apps/flutter/lib/services/deepfake_detector_service.dart` - LEVEL 2: Deepfake detection
- `apps/flutter/lib/services/agora_calling_service.dart` - Agora audio capture
- `apps/flutter/lib/services/in_app_calling_service.dart` - In-app call management
- `apps/flutter/lib/services/call_socket.dart` - WebSocket communication
- `apps/flutter/lib/screens_new/in_app_calling_screen.dart` - In-app call UI
- `apps/flutter/lib/screens_new/call/active_call_screen.dart` - Active call UI

### Backend API
- `apps/api/main.py` - FastAPI entry point
- `apps/api/api/voice/__init__.py` - Voice deepfake detection
- `apps/api/api/scam_detector.py` - Scam text analysis
- `apps/api/api/factcheck.py` - Fact-checking service

## 🚀 Development Commands

### Flutter
```bash
cd apps/flutter
flutter analyze lib/state/session_controller.dart
flutter run
flutter build apk
```

### Backend
```bash
cd apps/api
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## 📊 Performance Metrics

### Latency
- LEVEL 1 (Keywords): <1ms
- LEVEL 1 (ML): ~100ms
- LEVEL 2 (Deepfake - Local): ~200ms
- LEVEL 2 (Deepfake - Web): 1-4s (parallel with local, jo pehle aaye use karo)
- LEVEL 3 (Web - Text): 1-4s (only when needed)

### Accuracy
- LEVEL 1 (Keywords): 98.7%
- LEVEL 1 (ML): 85%+
- LEVEL 2 (Deepfake - Local): 75%
- LEVEL 2 (Deepfake - Web): High (multi-detector AI)
- LEVEL 3 (Web - Text): High (LLM + fact-checking)

### API Usage
- Typical call: 0-1 web calls (saved by local levels)
- Fact-checking calls: 1 call (necessary)
- Offline calls: 0 web calls (local only)

## 🎯 Testing

### Manual Testing
1. Start Agora call
2. Verify speakerphone is OFF
3. Verify audio capture via AudioFrameObserver
4. Check logs for local processing
5. Test offline mode (disable internet)
6. Test fact-checking (mention company/scheme)

### Key Logs
```
🔍 LEVEL 1 (Scam Text - LOCAL): SCAM DETECTED! Confidence: 92.3%
🔍 LEVEL 1 (Scam Text - LOCAL): UNCERTAIN (45.2%) → Going to LEVEL 3 (Web) for fact-checking
🔍 Fact-checking triggers detected → Going to LEVEL 3 (Web) for verification
📤 Escalating to LEVEL 3 (Web) for fact-checking: SBI Bank...
🤖 LEVEL 2 (Deepfake): DEEPFAKE DETECTED! Confidence: 72.0% (LOCAL)
🤖 LEVEL 2 (Deepfake): DEEPFAKE DETECTED! Confidence: 94.5% (WEB (FINAL))
🤖 LEVEL 2 (Deepfake): UNCERTAIN (LOCAL: 45.0%) → Escalating to LEVEL 3 (Web) for advanced voice analysis
📤 Escalating to LEVEL 3 (Web) for advanced voice analysis (3200 bytes)
📴 OFFLINE - Cannot escalate to LEVEL 3 (Web), relying on local result
```

## 🔒 Security Considerations

### Local Processing
- LEVEL 1 & LEVEL 2 work completely offline
- No data sent to backend unless necessary
- Privacy-preserving design

### Web Communication
- WebSocket for real-time audio streaming
- Binary PCM frames (efficient)
- JWT authentication
- Only called when needed

## 📝 Notes

### Audio Capture
- No speakerphone required (SDK-level capture)
- Captures REMOTE caller audio (not local microphone)
- Works completely offline
- 16kHz mono PCM format

### Scambaiter
- AI voice sent to remote scammer via Agora
- PCM → WAV conversion required by Agora
- Real-time delivery (<500ms)
- Manual activation after scam detection

### Offline Mode
- Automatic detection via ConnectivityMonitor
- Local levels provide full protection
- Web automatically skipped
- Seamless transition between online/offline
