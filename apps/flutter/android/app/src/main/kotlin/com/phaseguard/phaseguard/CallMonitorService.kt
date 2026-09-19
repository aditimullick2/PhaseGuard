package com.phaseguard.phaseguard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder

class CallMonitorService : Service() {
    private var tracker: PhoneCallTracker? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
        startForeground(NOTIFICATION_ID, buildNotification(title = "PhaseGuard", text = "Call protection is on", fullScreen = false))
        tracker = PhoneCallTracker(this).also { it.start() }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val state = intent?.getStringExtra(EXTRA_STATE)
        val number = intent?.getStringExtra(EXTRA_NUMBER)
        if (state != null) {
            PhoneCallEmitter.emit(state, number)
            if (state == "ringing" || state == "offhook") {
                bringAppToFront(state, number)
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        tracker?.stop()
        tracker = null
        super.onDestroy()
    }

    private fun bringAppToFront(state: String, number: String?) {
        val launch = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra(EXTRA_STATE, state)
            putExtra(EXTRA_NUMBER, number)
        }
        try {
            startActivity(launch)
        } catch (_: Exception) {
        }
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(
            NOTIFICATION_ID,
            buildNotification(
                title = "Incoming call — PhaseGuard",
                text = number ?: "Unknown caller",
                fullScreen = true,
                launchExtras = launch,
            ),
        )
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Call protection",
            NotificationManager.IMPORTANCE_HIGH,
        )
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(
        title: String,
        text: String,
        fullScreen: Boolean,
        launchExtras: Intent? = null,
    ): Notification {
        val launch = launchExtras ?: Intent(this, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            this,
            if (fullScreen) 0 else 1,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pending)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_CALL)
        if (fullScreen) {
            builder.setFullScreenIntent(pending, true)
        }
        return builder.build()
    }

    companion object {
        const val CHANNEL_ID = "phaseguard_calls"
        const val NOTIFICATION_ID = 7101
        const val EXTRA_STATE = "phone_state"
        const val EXTRA_NUMBER = "phone_number"
    }
}
