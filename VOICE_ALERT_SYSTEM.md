# Voice-Enabled Emergency Alert System

## Overview
When a fall is detected, the app now shows an **intelligent pre-alarm screen** with:
- 🎤 **Automatic voice recognition** - Listens for user confirmation
- 📊 **15-second countdown** - Time to cancel before SOS is sent
- 🔴 **Flashing red alert** - High contrast visual indicator
- 📱 **Tap to cancel** - Touch controls for accessibility
- 🔊 **Text-to-speech prompts** - Audio feedback at each step

---

## Fall Detection Flow

```
Sensor Impact Detected
         ↓
[Impact + Rotation + Stability Check]
         ↓
    onFallDetected()
         ↓
   PRE-ALARM SCREEN
         ↓
   [Voice Listening] or [Tap to Cancel]
         ↓
   ✅ User says "OK"  OR  ❌ 15 seconds expire
         ↓
  [SOS Triggered]
    - Call primary contact
    - Send SMS to all contacts
    - Send location via Google Maps
```

---

## Voice Input Features

### Voice Recognition Keywords
The system listens for confirmation words:
- ✅ **Confirmation words**: "okay", "ok", "i am okay", "yes", "fine", "alright"
- ✅ **Voice will cancel SOS if user confirms they're okay**
- ❌ **No match → Resume listening** for another 5 seconds

### Voice Status Display
The pre-alarm screen shows:
- 🎤 **Listening indicator** - Animated blue status when listening
- 📝 **Heard text** - Displays what the app heard
- ⏱️ **Countdown timer** - Real-time SOS countdown
- 📍 **Flashing alert** - Red background with pulsing effect

---

## Pre-Alarm Screen Behavior

### Visual & Audio
1. **Initialization**:
   - Vibration (500ms pulse)
   - TTS: "Fall detected. Are you okay? Say 'I am okay' or tap to cancel. Sending SOS in 15 seconds."

2. **Continuous Feedback**:
   - Red flashing background (on/off every 500ms)
   - Voice listening indicator with animation
   - Real-time transcription display
   - Countdown timer in large numbers

### User Actions
- **🎤 Say "I'm okay"** → Cancels immediately
  - TTS: "Thank you for confirming. Alarm canceled."
  
- **👆 Tap anywhere** → Cancels immediately
  - SnackBar: "Alarm canceled"
  
- **⏱️ Do nothing for 15 seconds** → Triggers SOS
  - TTS: "Sending SOS alert"
  - Calls emergency contacts
  - Sends SMS with GPS location

---

## Required Permissions

### iOS
Add to `ios/Runner/Info.plist`:
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>This app uses speech recognition to listen for voice confirmation when a fall is detected.</string>

<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to recognize voice responses during fall detection.</string>
```

### Android
Already in `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

---

## Code Integration

### Pre-Alarm Screen Import
```dart
import 'package:speech_to_text/speech_to_text.dart' as stt;

// Voice recognition
late stt.SpeechToText _speechToText;
String _spokenText = '';
```

### Fall Detection Trigger
```dart
void onFallDetected() {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PreAlarmScreen(
        onCancel: () {
          print('User canceled alarm');
        },
      ),
    ),
  );
}
```

### Voice Response Handling
```dart
void _checkVoiceResponse(String response) {
  if (okayKeywords.any((keyword) => response.contains(keyword))) {
    // Cancel SOS - user is okay
    _cancelAlarm();
  } else {
    // Resume listening
    _startVoiceListening();
  }
}
```

---

## Testing Voice Features

### Test without real fall:
```dart
// In advanced_fall_detector.dart UI
ElevatedButton(
  onPressed: () => onFallDetected(),
  child: Text('Test Fall Detection'),
)
```

### Voice Response Testing
1. **Test "I'm okay"**:
   - Tap Test button
   - Pre-alarm screen appears
   - Say "I'm okay" clearly
   - Alarm should cancel immediately

2. **Test "Help me"**:
   - Tap Test button
   - Pre-alarm screen appears
   - Say "Help me" (not a confirmation word)
   - Should continue listening

3. **Test 15-second timeout**:
   - Tap Test button
   - Do nothing for 15 seconds
   - Should trigger SOS (call + SMS)

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Microphone access denied" | Grant microphone permission in app settings |
| Voice not recognized | Speak clearly, check microphone is working |
| "Listening..." never stops | Check network (cloud-based recognition needs internet) |
| TTS not playing | Ensure volume is unmuted, check TTS settings |
| Pre-alarm screen not showing | Check Navigator context is available |

---

## Future Enhancements

- [ ] Custom voice confirmation words (user-defined)
- [ ] Multiple language support
- [ ] Machine learning to recognize user's voice
- [ ] Escalation if user doesn't respond
- [ ] Real-time audio playback of confirmed response
- [ ] Offline speech recognition (local ML model)
- [ ] Integration with smartwatch for responses

---

## Packages Used

- **speech_to_text** (v6.6.2) - Cloud-based speech recognition
- **flutter_tts** (v4.2.5) - Text-to-speech alerts
- **vibration** (v1.9.0) - Haptic feedback
- **geolocator** (v9.0.2) - GPS location capture
- **telephony** (v0.2.0) - Emergency calls & SMS

All packages already configured and ready to use! 🚀
