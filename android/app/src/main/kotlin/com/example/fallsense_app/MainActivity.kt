package com.example.fallsense_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    private val channelName = "com.fallsense/fall_detection"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "wakeScreenAndShowAlert" -> {
                        wakeScreenAndShowAlert()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Wake the screen and bring app to foreground
    private fun wakeScreenAndShowAlert() {
        try {
            // Get wake lock
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "FallSense::WakeLock"
            )
            wakeLock.acquire(3000) // 3 second hold

            // Unlock device if locked
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (keyguardManager.isKeyguardLocked) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    keyguardManager.requestDismissKeyguard(activity, null)
                }
            }

            // Add flags to window for full-screen display
            window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)

            // Bring app to foreground if in background
            bringToForeground()

            println("✅ Android: Screen wake initiated for fall alert")
        } catch (e: Exception) {
            println("❌ Android: Error waking screen: ${e.message}")
        }
    }

    /// Bring the app to foreground
    private fun bringToForeground() {
        val intent = intent.apply {
            flags = android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP or
                   android.content.Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        }
        startActivity(intent)
    }
}
