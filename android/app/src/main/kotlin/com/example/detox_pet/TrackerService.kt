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

class TrackerService : Service() {
    // ---- Test settings. Change these later. ----
    private val pollMs = 10_000L          // check every 10 s (use 60_000L later)
    private val thresholdMs = 60_000L     // alert after 1 min (use 15 * 60_000L later)
    private val blacklist = setOf(
        "com.google.android.youtube",
        "com.instagram.android"
        // Add the package names you saw in your own list, e.g. TikTok, Reddit.
    )

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
            if (screenOn) check()
            handler.postDelayed(this, pollMs)
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

    private fun check() {
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
        if (pkg != null && pkg in blacklist) {
            if (blacklistedSince == null) blacklistedSince = now
            val elapsed = now - blacklistedSince!!
            updateStatus("On $pkg for ${elapsed / 1000}s")
            if (elapsed >= thresholdMs && !alerted) {
                alerted = true
                sendAlert(elapsed / 60_000)
            }
        } else {
            blacklistedSince = null
            alerted = false
            updateStatus("Watching... now: $pkg")
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

    private fun sendAlert(minutes: Long) {
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val n = NotificationCompat.Builder(this, "alerts")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Hey. Scroller.")
            .setContentText("That's $minutes+ min of distraction. Put the phone down!")
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        getSystemService(NotificationManager::class.java).notify(2, n)
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        if (running) unregisterReceiver(screenReceiver)
        running = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}