# PhaseGuard Flutter Screens Implementation

## Overview
This document describes the new Flutter screens implemented based on the design screenshots, matching the backend capabilities.

## Screens Implemented

### 1. Incoming Call Overlay (`incoming_call_overlay.dart`)
**Purpose**: Overlay that appears when an incoming call is detected

**Features**:
- Caller avatar with electric teal gradient
- Phone number display
- Call status badge
- Number intelligence card showing:
  - VOIP detection status
  - Times reported
  - Registration circle
- Action buttons: "Ignore" and "Start Protection"

**Backend Data**: `number_intel` WebSocket message

### 2. Live Verify Dashboard (`live_verify_dashboard.dart`)
**Purpose**: Main real-time analysis screen during active calls

**Features**:
- PDI Score display (0.0-1.0) with visual gauge
- Verdict status badge (SAFE/SUSPICIOUS/SCAM)
- Verdict message card with appropriate styling
- Live transcript display with real-time indicator
- Evidence sources with clickable links
- Audio waveform visualization
- Connection status indicator

**Backend Data**: `pdi_update`, `factcheck_update`, `transcript_update`, `connected` messages

### 3. AI Voice Analysis (`ai_voice_analysis.dart`)
**Purpose**: Technical DSP metrics dashboard

**Features**:
- Large PDI Score display with confidence percentage
- Synthetic voice detection indicator
- Technical metrics (triads analyzed, compute time, sample rate)
- Ensemble analysis with score, label, and reasoning
- Micro-tremor analysis with energy and frequency data

**Backend Data**: `pdi_update`, `tremor_update`, `ensemble_update`, `hf_ml_update` messages

### 4. Scambaiter Active Session (`scambaiter_session.dart`)
**Purpose**: Scambaiter conversation management

**Features**:
- "CALL PROTECTED" status banner
- Conversation log with message bubbles (caller vs AI)
- Timestamp for each message
- Audio playback controls for AI responses
- Scambaiter toggle switch
- Real-time conversation display

**Backend Data**: `scambaiter_turn` messages, binary audio streaming

### 5. Call History & Logs (`call_history_logs.dart`)
**Purpose**: Post-call analysis review

**Features**:
- Call list with phone numbers, dates, times
- Verdict badges (SAFE/SCAM/SUSPICIOUS)
- Duration and peak PDI statistics
- Transcript preview
- "View Details" and "Report" buttons
- Detailed call view modal with full transcript

**Backend Data**: `CallSession` data (transcript_history, factcheck_history, etc.)

### 6. System Settings (`system_settings.dart`)
**Purpose**: App configuration

**Features**:
- Connection status indicator
- Backend WebSocket URL configuration
- Feature toggles:
  - AI Voice Detector
  - Scambaiter
  - Official Verified Alerts
- Operational mode status (full/limited)
- About section with version info

**Backend Data**: `config_info`, `mode_update` messages, SharedPreferences

### 7. Simple Call Interface (`simple_call_interface.dart`)
**Purpose**: Basic call interface

**Features**:
- Caller avatar with glow effect
- Phone number display
- Call status indicator
- Protection status toggle
- Answer/Reject buttons with visual feedback
- Protection enable/disable switch

**Backend Data**: `CallStateObserver` state, protection status

## Navigation Structure

The app uses a bottom navigation bar with three main tabs:
- **Home**: Main dashboard with quick actions and recent activity
- **History**: Call history and logs
- **Settings**: System configuration

From the Home screen, users can access:
- Live Verify Dashboard
- AI Voice Analysis
- Scambaiter Session
- Call History

## Color Theme

The implementation uses the premium dark-mode palette from the design:
- **Backgrounds**: Deep navy (#0A0F1E, #111827, #1E2A3A)
- **Accent**: Electric teal/cyan (#00D4FF)
- **Semantic**: Green (#22C55E), Amber (#F59E0B), Red (#EF4444)
- **Text**: Off-white (#F1F5F9), light gray (#94A3B8), dark gray (#475569)

## File Structure

```
lib/
├── main.dart (original)
├── main_design.dart (new design version)
├── screens_new/
│   ├── incoming_call_overlay.dart
│   ├── live_verify_dashboard.dart
│   ├── ai_voice_analysis.dart
│   ├── scambaiter_session.dart
│   ├── call_history_logs.dart
│   ├── system_settings.dart
│   ├── simple_call_interface.dart
│   └── app_navigation.dart
├── theme/
│   ├── tokens.dart (updated with new colors)
│   ├── tokens_old.dart (backup)
│   ├── app_theme.dart (updated)
│   └── app_theme_old.dart (backup)
```

## Usage

To use the new screens:

1. **For testing/development**:
   ```bash
   # Update main.dart to use the new design
   cd lib
   cp main_design.dart main.dart
   ```

2. **To integrate with existing backend**:
   - Replace mock data in each screen with real WebSocket data
   - Connect screens to the existing `SessionController`
   - Implement proper state management for real-time updates

3. **To restore original**:
   ```bash
   cd lib
   cp main_old.dart main.dart
   cd theme
   cp tokens_old.dart tokens.dart
   cp app_theme_old.dart app_theme.dart
   ```

## Backend Integration Points

Each screen needs to be connected to the corresponding backend WebSocket messages:

1. **Incoming Call Overlay**: `number_intel` message
2. **Live Verify Dashboard**: `pdi_update`, `factcheck_update`, `transcript_update`
3. **AI Voice Analysis**: `pdi_update`, `tremor_update`, `ensemble_update`
4. **Scambaiter Session**: `scambaiter_turn` messages
5. **Call History**: Session data from `CallSession`
6. **System Settings**: `config_info`, `mode_update`, SharedPreferences
7. **Simple Call Interface**: `CallStateObserver` state

## Next Steps

1. Connect screens to real WebSocket data
2. Implement proper state management
3. Add error handling and loading states
4. Integrate with existing `SessionController`
5. Add proper permissions handling
6. Test with real backend connection
7. Add animations and transitions
8. Implement deep linking for incoming calls

## Notes

- All screens use the new color scheme matching the design screenshots
- Screens are currently using mock data for demonstration
- The navigation structure is simple and can be expanded
- All screens follow Material 3 design guidelines
- Responsive design considerations are included
