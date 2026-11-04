package com.binarypulse.amarguard.sharing

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import com.binarypulse.amarguard.MainActivity
import com.binarypulse.amarguard.R

class SharingNotificationManager(private val context: Context) {

    companion object {
        const val CHANNEL_ID = "amarguard_family_safety_sharing"
        const val NOTIFICATION_ID = 4711
    }

    fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.sharing_channel_name),
            NotificationManager.IMPORTANCE_LOW
        )
        channel.description = context.getString(R.string.sharing_channel_description)
        channel.setShowBadge(false)
        manager.createNotificationChannel(channel)
    }

    fun buildNotification(): Notification {
        ensureChannel()
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(MainActivity.EXTRA_OPEN_FAMILY_SAFETY, true)
        }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val contentIntent = PendingIntent.getActivity(context, 0, openIntent, pendingFlags)
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(context.getString(R.string.sharing_notification_title))
            .setContentText(context.getString(R.string.sharing_notification_body))
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    context.getString(R.string.sharing_notification_body)
                )
            )
            .setSmallIcon(R.drawable.ic_sharing_notification)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentIntent(contentIntent)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    fun hasNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }
}
