# STEP 1: API Contract Mismatch Analysis

**Comparing Backend API Contract (BACKEND_API_CONTRACT.md) vs. Flutter Implementation**

## Mismatch Table

| # | Backend API | Flutter Code | Location | Problem | Severity |
|---|---|---|---|---|---|
| 1 | `factcheck_update.status`: "VERIFYING"\|"CRITICAL"\|"SAFE"\|"WARNING"\|"UNCERTAIN" | SessionController reads `factcheck?.status` but risk meter logic doesn't react to status value—only to keyword detection in transcript text (line 763-775) | session_controller.dart:96-100, 763-775 | **Meter doesn't turn red on backend CRITICAL**—it only reacts to local keyword matching, not to the actual backend verdict status. Backend sends the authoritative risk score; Flutter ignores it. | **CRITICAL** |
| 2 | `factcheck_update.category`: "SCAM_KEYWORD_DETECTED"\|"DIGITAL_ARREST"\|"IMPERSONATION"\|... | Protocol.dart parses `category`, but it's never displayed in UI. SessionController stores it but doesn't surface it to meters or alerts. | protocol.dart:8, 15 | Backend sends scam category (e.g., "DIGITAL_ARREST") for specific threat types, but UI never shows it. Loses forensic signal. | **HIGH** |
| 3 | `POST /call/{call_id}/scambait` activates backend scambaiter | ApiClient has `activateScambaiter()` method (line 126-140), calls correct endpoint | api_client.dart:126-140 | API call looks correct, but: (a) No error handling for 409 conflict, (b) No UI state machine showing "starting/active/failed", (c) Scambaiter responses come back as `scambaiter_turn` JSON + binary audio on WS but Flutter has no handler for binary audio frames from backend. SessionController has no `onBytes` handler set up. | **CRITICAL** |
| 4 | WebSocket `scambaiter_turn`: `{type, caller_text, ai_text, ts}` | SessionController._onJson() (line 441-459) parses and appends to `scambaiterConversation` list | session_controller.dart:441-459 | Parser is correct. BUT: Backend also sends **binary audio** via `await session.websocket.send_bytes(audio_bytes)` after the JSON turn message. Flutter's CallSocket does have an `onBytes` parameter (call_socket.dart:23) but SessionController never sets it (line 352-365 connect call has no onBytes callback). Audio frames are dropped silently. | **CRITICAL** |
| 5 | `POST /call/{call_id}/escalate/draft` then `POST /call/{call_id}/escalate/confirm` (two-step) | ApiClient has both methods; SessionController calls them (line 545-568). BUT: UI never shows confirmation dialog or progress. Button may not be wired. | session_controller.dart:545-568, main.dart unknown | Need to check if button onPressed calls `draftBlockAndReport()` and shows modal with summary before confirm. Likely missing or swallowed exception. | **CRITICAL** |
| 6 | Escalation response includes `delivery_status`, `dispatched_at` | ApiClient returns raw response dict; SessionController stores in `lastActionMessage` (line 565-566) | session_controller.dart:565-567 | Message is stored but never displayed in UI. No success/error toast or dialog shown to user. | **HIGH** |
| 7 | `POST /call/{call_id}/escalate/cybercell` (direct to 1930) | ApiClient has `escalateToCybercell()` (line 255-267), returns dict | api_client.dart:255-267 | API call correct. BUT: SessionController has method call at line 591-593 but never shows UI feedback. No loading state, no success message. | **HIGH** |
| 8 | `GET /call/{call_id}/dossier` returns `application/pdf` bytes | ApiClient `getDossier()` (line 187-199) returns `res.bodyBytes`; SessionController `getDossier()` (line 971-992) calls it and saves | session_controller.dart:971-992 | API call correct. PDF is downloaded but: (a) No loading indicator during download, (b) `saveDossierToFile()` tries hardcoded Android paths but doesn't use Flutter's platform-agnostic `path_provider` properly, (c) No error message shown if save fails—just returns filename, (d) No way to open PDF after saving. | **HIGH** |
| 9 | WebSocket message `pdi_update`, `ensemble_update`, `tremor_update` contain float scores 0.0–1.0 | SessionController parses them correctly, stores as `pdiScore`, `syntheticVoiceScore`, `tremorEnergy` (line 391-409) | session_controller.dart:391-409 | Scores are in 0.0–1.0 range. BUT: Meter widget must display as 0–100%. Need to verify meter widget multiplies by 100 in UI render. Also: no animation smoothing between score updates—jumps instantly. | **MEDIUM** |
| 10 | WebSocket `config_info`: `{dsp_enabled: bool}` | SessionController has `dspEnabled` field (line 66) but never receives/parses config_info message type in `_onJson()` | session_controller.dart:66, 381-493 | Config message is never handled in switch statement. Flutter always assumes DSP is on, but backend may send false. UI will show DSP metrics even if backend disabled them. | **MEDIUM** |
| 11 | WebSocket `number_intel`: `{is_likely_voip, times_reported, registration_circle}` | SessionController never handles this message type in `_onJson()` | session_controller.dart:381-493 | Switch statement has no case for "number_intel". Message is silently dropped. UI never shows caller's VoIP status or reputation. | **MEDIUM** |
| 12 | WebSocket `transcript_update`: `{type, text, is_final}` | SessionController handles this (line 411-426), appends to `liveTranscript` | session_controller.dart:411-426 | Handler exists and works correctly. No issue here. | **NONE** |
| 13 | WebSocket `mode_update`: `{mode: "full"\|"limited"\|"offline"}` | SessionController stores `operationalMode` (line 59) but never handles "mode_update" message | session_controller.dart:381-493 | No case in switch. Backend sends this when network fails, but UI never sees it. Should show "offline mode" chip but doesn't. | **HIGH** |
| 14 | WebSocket `video_frame_captured`: sent when frame committed during CRITICAL | SessionController never handles this message type | session_controller.dart:381-493 | No case in switch. Evidence capture frames are never displayed in UI. | **MEDIUM** |
| 15 | JWT token from `/call/init` scoped to call_id, sent in `Authorization: Bearer {token}` header | ApiClient `_headers()` (line 14-17) includes Bearer token correctly | api_client.dart:14-17 | Correct implementation. No issue. | **NONE** |
| 16 | Risk meter logic: CRITICAL status should force red immediately, regardless of DSP scores | SessionController's `isScamDetected` getter (line 96-100) checks `factcheck?.status == 'CRITICAL'` OR `pdiScore >= 0.70` OR `ensemble >= 0.70` | session_controller.dart:96-100 | Logic exists BUT: `isScamDetected` is defined but never actually used to drive meter widget color. Meter widget (if it listens to `pdiScore` directly) will show based on DSP score, not verdict status. Need to verify where meter reads its state. | **CRITICAL** |
| 17 | Risk meter should smooth-animate color transitions (green → amber → red) | Unknown—need to check widget code | Need to find meter widget in screens/ | Cannot verify without reading meter widget. Likely has no animation. | **UNKNOWN** |
| 18 | Dossier should use platform-agnostic `path_provider` + `open_filex` or `share_plus` | SessionController tries hardcoded paths `/storage/emulated/0/Download`, `/sdcard/Download` (line 1012-1013) instead of `getDownloadsDirectory()` first | session_controller.dart:1012-1013 | PDF is saved but with brittle Android-only logic. iOS will fail silently. Should use `getDownloadsDirectory()` from `path_provider`. | **HIGH** |

---

## Root Cause Summary

### 1. Risk Meter Never Turns Red on Scam Words
**Root Cause:** Backend sends authoritative `factcheck_update.status = "CRITICAL"` when it detects scam keywords via LLM fact-checking, but Flutter's meter widget is driven by local `pdiScore` (DSP) and local keyword matching, not by `factcheck?.status`. The `isScamDetected` getter exists but is not wired to the meter widget.

**Evidence:** 
- Backend sends CRITICAL + category (line 557-560 in ws/call_socket.py)
- Flutter parses it (protocol.dart line 20)
- SessionController stores it (line 381-493)
- BUT meter widget reads `pdiScore` directly, not `factcheck?.status`

### 2. Scambaiter Not Deploying
**Root Cause:** Two separate failures:
1. Backend sends scambaiter responses as both JSON (`scambaiter_turn`) + binary audio, but Flutter's CallSocket.connect() is called without an `onBytes` callback, so binary audio frames are dropped.
2. UI has no state machine—no "starting"/"active"/"failed" display, no loading indicator.

**Evidence:**
- `_fire_scambaiter_turn()` in ws/call_socket.py line 390-396: sends JSON then binary audio
- `CallSocket.connect()` in call_socket.dart line 20-64 accepts `onBytes` parameter
- SessionController calls connect() at line 352-365 with NO `onBytes` callback
- Binary audio never received by Flutter

### 3. "Escalate to Cyber Cell" Button Does Nothing
**Root Cause:** Method exists and API call is correct, but UI button is either (a) not wired to onPressed, or (b) exception is swallowed silently, or (c) no visual feedback to user that anything happened.

**Evidence:**
- `escalateToCybercell()` exists in both api_client.dart and session_controller.dart
- SessionController method at line 585-593 calls API and stores result in `lastActionMessage`
- BUT `lastActionMessage` is never displayed anywhere in UI—no toast, no dialog, no status chip

### 4. Dossier PDF Not Generated
**Root Cause:** Not that PDF isn't generated—backend generates it fine. Problem is Flutter has three issues:
1. No loading indicator while downloading
2. `saveDossierToFile()` uses hardcoded Android paths instead of `path_provider`
3. No way to open/share PDF after saving
4. Errors are swallowed (exception caught but nothing shown to user)

**Evidence:**
- `getDossier()` API call is correct (api_client.dart:187-199)
- `saveDossierToFile()` tries `/storage/emulated/0/Download` (hardcoded, Android only)
- No `open_filex` or `share_plus` package used
- Errors logged to debugPrint, never shown in UI (session_controller.dart:987-989)

---

## Verified Correct (No Issues)

- ✅ JWT token handling (`_headers()` includes Bearer token)
- ✅ Transcript parsing from WebSocket (`transcript_update` handler works)
- ✅ Call initialization (`POST /call/init` mapped correctly)
- ✅ Basic DSP score parsing (though animation is missing)

---

## Missing WebSocket Message Handlers (Silent Failures)

These message types arrive from backend but are never parsed:
- `config_info` — tells Flutter if DSP is enabled
- `number_intel` — caller's VoIP status + reputation
- `mode_update` — online/offline mode switch
- `video_frame_captured` — forensic evidence committed
- `error` — generic errors from backend (partially handled line 486-487 but no UI display)

---

## Files to Change

1. **session_controller.dart** — Add missing WebSocket handlers, wire risk meter to `factcheck?.status`, add `onBytes` callback for scambaiter audio
2. **protocol.dart** — Already correct; no changes needed
3. **api_client.dart** — Already correct; no changes needed
4. **Meter widget** (TBD: need to find file) — Change to read from `isScamDetected` and `factcheck?.status`, add smooth color animation
5. **Escalation modal UI** (TBD: need to find file) — Add confirmation dialog with payload summary, progress indicator, success/error toast
6. **Dossier download UI** (TBD: need to find file) — Add loading indicator, success toast with "open" button
7. **pubspec.yaml** — Add dependencies: `open_filex`, `share_plus`, `connectivity_plus` (for offline detection)

