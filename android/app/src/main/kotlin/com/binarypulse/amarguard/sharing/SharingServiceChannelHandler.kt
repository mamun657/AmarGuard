package com.binarypulse.amarguard.sharing

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SharingServiceChannelHandler(
    private val activityProvider: () -> android.app.Activity?
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "com.binarypulse.amarguard/sharing_service"
        const val EVENT_CHANNEL = "com.binarypulse.amarguard/sharing_service_events"
    }

    private var eventSink: EventChannel.EventSink? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val activity = activityProvider()
        val context = activity ?: run {
            result.error("no_activity", "Activity is not available.", null)
            return
        }
        when (call.method) {
            "startService" -> {
                val sessionId = call.argument<String>("sessionId") ?: ""
                val intervalSeconds = call.argument<Int>("intervalSeconds") ?: 90
                val distanceFilter = call.argument<Int>("distanceFilterMeters") ?: 20
                val started = startService(context, sessionId, intervalSeconds, distanceFilter)
                result.success(started)
            }
            "pauseService" -> {
                context.startService(FamilyLocationService.pauseIntent(context))
                result.success(true)
            }
            "resumeService" -> {
                val sessionId = call.argument<String>("sessionId") ?: ""
                context.startService(FamilyLocationService.resumeIntent(context, sessionId))
                result.success(true)
            }
            "stopService" -> {
                context.startService(FamilyLocationService.stopIntent(context))
                result.success(true)
            }
            "status" -> {
                result.success(FamilyLocationService.stateProvider?.invoke())
            }
            "openNotificationSettings" -> {
                result.success(openNotificationSettings(context))
            }
            else -> result.notImplemented()
        }
    }

    private fun startService(
        context: android.content.Context,
        sessionId: String,
        intervalSeconds: Int,
        distanceFilterMeters: Int
    ): Boolean {
        return try {
            val intent = FamilyLocationService.startIntent(
                context,
                sessionId,
                intervalSeconds,
                distanceFilterMeters
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            true
        } catch (securityException: SecurityException) {
            false
        } catch (illegalStateException: IllegalStateException) {
            false
        }
    }

    private fun openNotificationSettings(context: android.content.Context): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (activityNotFoundException: android.content.ActivityNotFoundException) {
            false
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        FamilyLocationService.eventListener = { payload ->
            eventSink?.success(payload)
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        FamilyLocationService.eventListener = null
    }
}
