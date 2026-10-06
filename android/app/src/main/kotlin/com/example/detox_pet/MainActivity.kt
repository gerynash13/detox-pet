package com.example.detox_pet

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import android.Manifest
import android.os.Build
import androidx.core.content.ContextCompat

class MainActivity : FlutterActivity() {
    private val channelName = "detox_pet/usage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "openUsageSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "getRecentEvents" -> result.success(getRecentEvents())
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
                        }
                        result.success(null)
                    }
                    "startTracker" -> {
                        ContextCompat.startForegroundService(this, Intent(this, TrackerService::class.java))
                        result.success(null)
                    }
                    "stopTracker" -> {
                        stopService(Intent(this, TrackerService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    // Returns "time  package" lines for apps that came to the foreground in the last hour.
    private fun getRecentEvents(): List<String> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - 60 * 60 * 1000, now)
        val event = UsageEvents.Event()
        val fmt = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
        val lines = mutableListOf<String>()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                lines.add("${fmt.format(Date(event.timeStamp))}  ${event.packageName}")
            }
        }
        return lines.reversed() // newest first
    }
}