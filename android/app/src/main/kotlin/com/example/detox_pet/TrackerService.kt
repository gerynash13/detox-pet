package com.example.detox_pet

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject

class TrackerService : Service() {
    private class Config(
    val thresholdMs: Long,
    val pollMs: Long,
    val apps: Map<String, String>
)

    private fun loadConfig(): Config {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.tracker_config", null)
        var minutes = 15
        val apps = mutableMapOf<String, String>()
        if (raw != null) {
            try {
                val obj = JSONObject(raw)
                minutes = obj.optInt("thresholdMinutes", 15)
                val arr = obj.optJSONArray("apps")
                if (arr != null) {
                    for (i in 0 until arr.length()) {
                        val a = arr.getJSONObject(i)
                        apps[a.getString("pkg")] = a.getString("name")
                    }
                }
            } catch (_: Exception) {
                // bad or missing settings: fall back to defaults
            }
        }
        // Short limits = test mode, so poll faster. Otherwise once a minute.
        val poll = if (minutes <= 2) 10_000L else 60_000L
        return Config(minutes * 60_000L, poll, apps)
    }

    private val handler = Handler(Looper.getMainLooper())
    private var running = false
    private var screenOn = true
    private var currentPkg: String? = null
    private var lastQuery = 0L
    private var blacklistedSince: Long? = null
    private var alerted = false

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_OFF) {
                screenOn = false
                blacklistedSince = null // a locked screen counts as a break
                alerted = false
            } else if (intent.action == Intent.ACTION_SCREEN_ON) {
                screenOn = true
            }
        }
    }

    private val tick = object : Runnable {
        override fun run() {
            val cfg = loadConfig()
            if (screenOn) check(cfg)
            handler.postDelayed(this, cfg.pollMs)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannels()
        val n = statusNotification("Watching...")
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, n)
        }
        if (!running) {
            running = true
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            }
            if (Build.VERSION.SDK_INT >= 33) {
                registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(screenReceiver, filter)
            }
            handler.post(tick)
        }
        return START_STICKY
    }

    private fun check(cfg: Config) {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val from = if (lastQuery == 0L) now - 60 * 60 * 1000 else lastQuery
        val events = usm.queryEvents(from, now)
        val e = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            if (e.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) currentPkg = e.packageName
        }
        lastQuery = now

        val pkg = currentPkg
        val appName = if (pkg != null) cfg.apps[pkg] else null
        if (appName != null) {
            if (blacklistedSince == null) blacklistedSince = now
            val elapsed = now - blacklistedSince!!
            updateStatus("On $appName for ${elapsed / 1000}s")
            if (elapsed >= cfg.thresholdMs && !alerted) {
                alerted = true
                sendAlert(appName, elapsed / 60_000)
            }
        } else {
            blacklistedSince = null
            alerted = false
            updateStatus("Watching... now: ${labelFor(pkg)}")
        }
    }

    private fun labelFor(pkg: String?): String {
        if (pkg == null) return "unknown"
        return try {
            val info = packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: Exception) {
            pkg // apps without a launcher icon (system screens etc.) keep the package name
        }
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(
                NotificationChannel("tracker", "Tracker status", NotificationManager.IMPORTANCE_LOW))
            nm.createNotificationChannel(
                NotificationChannel("alerts", "Pet alerts", NotificationManager.IMPORTANCE_HIGH))
        }
    }

    private fun statusNotification(text: String) =
        NotificationCompat.Builder(this, "tracker")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setContentTitle("Pet is watching")
            .setContentText(text)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .build()

    private fun updateStatus(text: String) {
        getSystemService(NotificationManager::class.java).notify(1, statusNotification(text))
    }

    private fun sendAlert(appName: String, minutes: Long) {
        logIntervention(appName, minutes)
        val intent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra("alert_app", appName)
            .putExtra("alert_minutes", minutes)
        val open = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val n = NotificationCompat.Builder(this, "alerts")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Hey. Scroller.")
            .setContentText("Still on $appName? Tap to face your pet.")
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        getSystemService(NotificationManager::class.java).notify(2, n)
    }

    private fun logIntervention(appName: String, minutes: Long) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val old = try {
            JSONArray(prefs.getString("flutter.interventions", "[]") ?: "[]")
        } catch (_: Exception) {
            JSONArray()
        }
        old.put(
            JSONObject()
                .put("t", System.currentTimeMillis())
                .put("app", appName)
                .put("min", minutes)
        )
        // Keep only the newest 200 entries so the file never grows forever.
        val trimmed = JSONArray()
        val start = maxOf(0, old.length() - 200)
        for (i in start until old.length()) trimmed.put(old.get(i))
        prefs.edit().putString("flutter.interventions", trimmed.toString()).apply()
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        if (running) unregisterReceiver(screenReceiver)
        running = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}