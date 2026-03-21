# Background IMU Fall Detection Implementation

## Overview
FallSense now implements **true background fall detection** that runs continuously even when the app is closed or minimized. This document explains the architecture and integration.

## Architecture Components

### 1. Background IMU Service (`lib/services/background_imu_service.dart`)
- Runs in a separate isolate managed by `flutter_background_service`
- Continuously monitors accelerometer and gyroscope data
- Implements the same 3-step fall detection algorithm as foreground
- Uses `wakelock_plus` to keep device awake during monitoring

**Key Features:**
- Lightweight sensor processing (100ms check intervals)
- State machine for fall detection (impact → inactivity → stability)
- Triggers fallDetected event when fall confirmed
- Graceful cleanup on service stop

### 2. Notification Service (`lib/services/notification_service.dart`)
- High-priority notifications for fall alerts
- Full-screen intent on Android (shows even when locked)
- Sound, vibration, and visual indicators
- Action buttons for "I'm OK" and "Send SOS" responses

### 3. Main App Integration (`lib/main.dart`)
- Initializes `NotificationService` early in app lifecycle
- Initializes and configures `BackgroundIMUService`
- Listens for background fall detection events via `FlutterBackgroundService`
- Routes incoming fall alerts to PreAlarmScreen

### 4. Android Native Configuration (`MainActivity.kt`)
- `wakeScreenAndShowAlert()` method to wake device from background
- Handles keyguard dismissal for locked screens
- Sets window flags for full-screen display:
  - `FLAG_TURN_SCREEN_ON`: Wake the screen
  - `FLAG_SHOW_WHEN_LOCKED`: Display over lock screen
  - `FLAG_DISMISS_KEYGUARD`: Bypass lock screen

## Android Manifest Permissions

```xml
<!-- Background sensor monitoring permissions -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SENSORS" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.DISABLE_KEYGUARD" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

## iOS Configuration

Added to `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
    <string>voip</string>
</array>

<key>NSMotionUsageDescription</key>
<string>FallSense uses motion sensors to detect falls and help you stay safe</string>
```

## Fall Detection Algorithm (Background)

### Step 1: Impact + Rotation Detection
- **Acceleration Threshold**: > 20.0 m/s²
- **Gyroscope Threshold**: Adaptive (2.4-3.0 rad/s based on device orientation)
- **Spin Filter**: Ignores extreme rotation (> 12.0 rad/s) to avoid false positives from phone throws
- **Slope Detection**: Requires rapid deceleration (< -5.0 m/s²) OR high acceleration spike

### Step 2: Inactivity Verification (500-2000ms after impact)
- **Gravity Detection**: Device at rest, acceleration 9.5-10.8 m/s²
- **Stability Counting**: Must achieve 5+ stable readings
- **Progressive Relaxation**: Thresholds relax over time to allow for natural motion after fall

### Step 3: Stability Confirmation
- **Minimum Readings**: 5+ consecutive readings in gravity range
- **Window Duration**: Falls detected within 1.5 seconds of impact confirmation
- **Cooldown Period**: 5-second minimum between successive fall alerts

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Background IMU Service (Separate Isolate)                  │
│  - Reads accelerometer/gyroscope continuously              │
│  - Runs fall detection algorithm every 100ms               │
│  - Maintains state machine across sensor events            │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   │ onFallDetected()
                   │ service.invoke('fallDetected')
                   ▼
┌──────────────────────────────────────────────────────────────┐
│  Main App (Dart Layer)                                       │
│  - Listens: service.on('fallDetected').listen(...)          │
│  - Shows notification with high priority                    │
│  - Navigates to PreAlarmScreen                              │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   │ Native Platform Layer
                   ▼
┌──────────────────────────────────────────────────────────────┐
│  Android/iOS Native                                          │
│  - Android: Wakes screen, shows full-screen alert           │
│  - iOS: Presents notification with high priority            │
└──────────────────────────────────────────────────────────────┘
```

## Tuning Parameters

Located in `BackgroundIMUService`:

```dart
static const double accThreshold = 20.0;      // Impact magnitude
static const double gyroThreshold = 3.0;      // Rotation magnitude
static const double minAcc = 12.0;            // Minimum acceleration
static const double maxGyro = 12.0;           // Phone throw threshold
static const int cooldownSec = 5;             // Between alerts
static const int stabilityThreshold = 5;      // Readings required
```

## Testing Background Detection

### On Device (App Running):
1. Open MainDashboard
2. Tap "Test Fall Detection" button
3. PreAlarmScreen should appear with 15-second countdown

### With App Closed:
1. Open app and navigate to MainDashboard
2. Close/minimize the app completely
3. Simulate a fall (device free-fall + rapid deceleration)
4. Notification should appear and PreAlarmScreen launch

### Triggering from Background:
- Device must have sensors_plus library initialized
- BackgroundIMUService must be started and running
- Fall detection algorithm must confirm 3-step process

## Known Limitations

1. **Battery Impact**: Continuous background monitoring uses ~5-10% additional battery per hour
2. **iOS Background Limitations**: iOS restricts long-running background processes; fallback to periodic wakeups every 15-30 minutes
3. **Device Variability**: Accelerometer/gyroscope calibration varies by device; thresholds may need adjustment
4. **Wake Lock Duration**: Android's screen wake lock is limited to 3 seconds; notification is still shown

## Troubleshooting

### Background Service Not Starting
- Check Android permissions in AndroidManifest.xml
- Verify `FlutterBackgroundService` is initialized in main.dart
- Look for log messages starting with `🔄` or `🛑`

### PreAlarmScreen Not Appearing
- Check notification listener is registered in main.dart
- Verify fallDetected event is being broadcast from background service
- Check app navigation setup in MaterialApp.onGenerateRoute

### False Positives
- Increase `accThreshold` from 20.0 to 22.0
- Increase `stabilityThreshold` from 5 to 7
- Reduce `gyroThreshold` from 3.0 to 2.5

### Battery Drain Issues
- Increase timer interval from 100ms to 200-500ms in onStart()
- Reduce foreground service notification updates
- Implement periodic pause/resume logic based on user activity

## Dependencies

- `flutter_background_service`: ^5.0.0
- `flutter_background_service_android`: ^6.3.1
- `flutter_background_service_ios`: ^5.0.3
- `flutter_local_notifications`: ^17.0.0
- `wakelock_plus`: ^1.2.0
- `sensors_plus`: ^1.4.0

## Future Enhancements

1. **ML-Based Detection**: Replace threshold-based detection with ML model for better accuracy
2. **Multi-Sensor Fusion**: Incorporate barometer for altitude change detection
3. **User-Specific Thresholds**: Allow per-user calibration based on body metrics
4. **GPS Tracking**: Background location updates every 5 minutes for better emergency response
5. **WiFi/Cellular Offloading**: Reduce power consumption by pausing during charging
