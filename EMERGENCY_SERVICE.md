# Emergency Call & GPS Location Integration

## Overview
The app now includes **Emergency Service** that automatically triggers when a fall is confirmed:
1. 📍 **GPS Location Capture** - Gets current location with high accuracy
2. 📨 **Emergency SMS** - Sends SMS with location link and message
3. 📞 **Emergency Call** - Initiates automatic call to primary contact

---

## Required Permissions (Android)

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Location -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Calling -->
<uses-permission android:name="android.permission.CALL_PHONE" />

<!-- SMS -->
<uses-permission android:name="android.permission.SEND_SMS" />
<uses-permission android:name="android.permission.READ_SMS" />
```

---

## API Reference

### EmergencyService

#### `initialize()`
```dart
await EmergencyService.initialize();
```
- Requests location and SMS permissions
- Call this when app starts

#### `getCurrentLocation()`
```dart
final position = await EmergencyService.getCurrentLocation();
if (position != null) {
  print('Lat: ${position.latitude}, Lng: ${position.longitude}');
}
```
- Returns GPS coordinates with high accuracy
- Returns `null` if location unavailable

#### `makeEmergencyCall(String phoneNumber)`
```dart
final success = await EmergencyService.makeEmergencyCall('9876543210');
if (success) {
  print('Call initiated');
}
```
- Initiates automatic call to given number
- Returns `true` if successful

#### `sendEmergencySMS({required String phoneNumber, required String message, Position? location})`
```dart
final success = await EmergencyService.sendEmergencySMS(
  phoneNumber: '9876543210',
  message: '🆘 FALL DETECTED - I need help!',
  location: position,
);
```
- Sends SMS with optional location
- Location includes Google Maps link
- Returns `true` if successful

#### `triggerEmergencyResponse({required String phoneNumber, required String contactName})`
```dart
await EmergencyService.triggerEmergencyResponse(
  phoneNumber: '9876543210',
  contactName: 'Mom',
);
```
- Complete flow: Get location → Send SMS → Make call
- Automatically includes location in SMS

#### `sendToMultipleContacts({required List<String> phoneNumbers, required List<String> contactNames})`
```dart
await EmergencyService.sendToMultipleContacts(
  phoneNumbers: ['9876543210', '9876543211'],
  contactNames: ['Mom', 'Dad'],
);
```
- Sends to all contacts with delays
- Calls primary contact (first in list)

---

## Integration with Fall Detection

The `FallDetectionEngine` now automatically:
1. Detects confirmed fall
2. Waits 15 seconds for user confirmation
3. If not cancelled, calls `_sendSOS()`
4. `_sendSOS()` triggers emergency response via `EmergencyService`

### Example Usage in UI

```dart
import 'package:fallsense_app/services/emergency_service.dart';

// Initialize on app start
void initState() {
  super.initState();
  EmergencyService.initialize();
}

// Manually trigger for testing
ElevatedButton(
  onPressed: () async {
    await EmergencyService.triggerEmergencyResponse(
      phoneNumber: '+919876543210',
      contactName: 'Emergency Contact',
    );
  },
  child: Text('Test Emergency Call'),
)
```

---

## SMS Message Format

When fall is detected:

```
🆘 FALL DETECTED - I need help! This is an automated alert from FallSense.

📍 Location: 12.971599, 77.594566
🔗 https://maps.google.com/?q=12.971599,77.594566
```

---

## Phone Number Format Support

Both formats work:
- `9876543210` (without country code)
- `+919876543210` (with country code)

Numbers are automatically cleaned (spaces, dashes removed).

---

## Logging Output

The service provides detailed logs:

```
📍 Location obtained: 12.971599, 77.594566
📨 Sending emergency SMS to: 9876543210
✅ Emergency SMS sent to 9876543210
📞 Initiating emergency call to: 9876543210
✅ Emergency call initiated to 9876543210
✅ Emergency response completed
```

---

## Testing Checklist

- [ ] Permissions granted in app settings
- [ ] Test location capture with high accuracy
- [ ] Test SMS to real number (verify message)
- [ ] Test call initiation (verify call received)
- [ ] Test with multiple contacts
- [ ] Test with poor location (verify graceful handling)
- [ ] Test emergency response during fall detection

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Location permission denied" | Grant location access in Settings → Permissions |
| "SMS not received" | Check SMS permission, verify phone number |
| "Call not initiated" | Check call permission, verify phone number format |
| "No contacts available" | Add emergency contact in app UI |
| "Location timeout" | Ensure GPS is enabled, good signal |

---

## Future Enhancements

- [ ] WhatsApp/Telegram integration
- [ ] Voice message with fall details
- [ ] Real-time location tracking
- [ ] Emergency contact verification
- [ ] One-click test alerts
