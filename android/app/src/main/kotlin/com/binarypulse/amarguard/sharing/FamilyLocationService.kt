package com.binarypulse.amarguard.sharing

import android.Manifest
import android.annotation.SuppressLint
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.content.SharedPreferences
import androidx.core.content.ContextCompat

class FamilyLocationService : Service() {

    companion object {
        const val ACTION_START = "com.binarypulse.amarguard.sharing.START"
        const val ACTION_PAUSE = "com.binarypulse.amarguard.sharing.PAUSE"
        const val ACTION_RESUME = "com.binarypulse.amarguard.sharing.RESUME"
        const val ACTION_STOP = "com.binarypulse.amarguard.sharing.STOP"
        const val EXTRA_SESSION_ID = "session_id"
        const val EXTRA_INTERVAL_SECONDS = "interval_seconds"
        const val EXTRA_DISTANCE_FILTER_METERS = "distance_filter_meters"

        @Volatile
        var eventListener: ((Map<String, Any?>) -> Unit)? = null

        @Volatile
        var stateProvider: (() -> Map<String, Any?>)? = null

        fun startIntent(context: Context, sessionId: String, intervalSeconds: Int, distanceFilterMeters: Int): Intent {
            return Intent(context, FamilyLocationService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_SESSION_ID, sessionId)
                putExtra(EXTRA_INTERVAL_SECONDS, intervalSeconds)
                putExtra(EXTRA_DISTANCE_FILTER_METERS, distanceFilterMeters)
            }
        }

        fun pauseIntent(context: Context): Intent {
            return Intent(context, FamilyLocationService::class.java).apply {
                action = ACTION_PAUSE
            }
        }

        fun resumeIntent(context: Context, sessionId: String): Intent {
            return Intent(context, FamilyLocationService::class.java).apply {
                action = ACTION_RESUME
                putExtra(EXTRA_SESSION_ID, sessionId)
            }
        }

        fun stopIntent(context: Context): Intent {
            return Intent(context, FamilyLocationService::class.java).apply {
                action = ACTION_STOP
            }
        }
    }

    private lateinit var locationManager: LocationManager
    private lateinit var notificationManager: SharingNotificationManager
    private lateinit var preferences: SharedPreferences

    @Volatile
    private var running = false

    @Volatile
    private var paused = false

    @Volatile
    private var sessionId: String = ""

    @Volatile
    private var intervalSeconds = 90

    @Volatile
    private var distanceFilterMeters = 20

    @Volatile
    private var lastLatitude: Double? = null

    @Volatile
    private var lastLongitude: Double? = null

    @Volatile
    private var lastAccuracy: Double? = null

    @Volatile
    private var lastCapturedAt: Long? = null

    @Volatile
    private var lastError: String? = null

    private val listener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            publishLocation(location)
        }

        @Deprecated("Deprecated in Java")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

        override fun onProviderEnabled(provider: String) = Unit

        override fun onProviderDisabled(provider: String) {
            lastError = "location_service_disabled"
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        notificationManager = SharingNotificationManager(this)
        preferences = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        notificationManager.ensureChannel()
        stateProvider = {
            mapOf(
                "running" to running,
                "paused" to paused,
                "latitude" to lastLatitude,
                "longitude" to lastLongitude,
                "accuracy" to lastAccuracy,
                "capturedAt" to lastCapturedAt,
                "sessionId" to sessionId,
                "error" to lastError
            )
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            sessionId = preferences.getString(EXTRA_SESSION_ID, "") ?: ""
            intervalSeconds = preferences.getInt(EXTRA_INTERVAL_SECONDS, intervalSeconds)
            distanceFilterMeters = preferences.getInt(
                EXTRA_DISTANCE_FILTER_METERS,
                distanceFilterMeters
            )
            if (sessionId.isNotEmpty()) startForegroundTracking()
            return START_STICKY
        }
        when (intent?.action) {
            ACTION_START -> {
                sessionId = intent.getStringExtra(EXTRA_SESSION_ID) ?: sessionId
                intervalSeconds = intent.getIntExtra(EXTRA_INTERVAL_SECONDS, intervalSeconds)
                distanceFilterMeters = intent.getIntExtra(EXTRA_DISTANCE_FILTER_METERS, distanceFilterMeters)
                preferences.edit()
                    .putString(EXTRA_SESSION_ID, sessionId)
                    .putInt(EXTRA_INTERVAL_SECONDS, intervalSeconds)
                    .putInt(EXTRA_DISTANCE_FILTER_METERS, distanceFilterMeters)
                    .apply()
                startForegroundTracking()
            }
            ACTION_PAUSE -> pauseTracking()
            ACTION_RESUME -> {
                sessionId = intent.getStringExtra(EXTRA_SESSION_ID) ?: sessionId
                resumeTracking()
            }
            ACTION_STOP -> stopTracking()
        }
        return START_STICKY
    }

    @SuppressLint("MissingPermission")
    private fun startForegroundTracking() {
        if (!hasLocationPermission()) {
            lastError = "location_permission_missing"
            stopSelf()
            return
        }
        val notification = notificationManager.buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                SharingNotificationManager.NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(SharingNotificationManager.NOTIFICATION_ID, notification)
        }
        running = true
        paused = false
        lastError = null
        registerLocationUpdates()
    }

    @SuppressLint("MissingPermission")
    private fun registerLocationUpdates() {
        if (!hasLocationPermission()) return
        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER
        )
        var registered = false
        for (provider in providers) {
            try {
                if (!locationManager.isProviderEnabled(provider)) continue
                locationManager.requestLocationUpdates(
                    provider,
                    intervalSeconds * 1000L,
                    0f,
                    listener,
                    android.os.Looper.getMainLooper()
                )
                registered = true
            } catch (securityException: SecurityException) {
                lastError = "location_permission_missing"
            } catch (illegalArgumentException: IllegalArgumentException) {
                lastError = "provider_unavailable"
            }
        }
        if (!registered) {
            lastError = "no_location_provider"
        }
        seedLastKnownLocation()
    }

    @SuppressLint("MissingPermission")
    private fun seedLastKnownLocation() {
        if (!hasLocationPermission()) return
        try {
            val best = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                ?: locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            if (best != null && best.time >= System.currentTimeMillis() - MAX_SEED_AGE_MS) {
                publishLocation(best)
            }
        } catch (securityException: SecurityException) {
            lastError = "location_permission_missing"
        }
    }

    private fun pauseTracking() {
        if (!running) return
        paused = true
        removeLocationUpdates()
    }

    private fun resumeTracking() {
        if (!running) {
            startForegroundTracking()
            return
        }
        paused = false
        registerLocationUpdates()
    }

    private fun stopTracking() {
        running = false
        paused = false
        removeLocationUpdates()
        stopForeground(STOP_FOREGROUND_REMOVE)
        preferences.edit().clear().apply()
        stopSelf()
    }

    private fun removeLocationUpdates() {
        try {
            locationManager.removeUpdates(listener)
        } catch (securityException: SecurityException) {
            lastError = "location_permission_missing"
        }
    }

    private fun publishLocation(location: Location) {
        lastLatitude = location.latitude
        lastLongitude = location.longitude
        lastAccuracy = if (location.hasAccuracy()) location.accuracy.toDouble() else null
        lastCapturedAt = location.time
        lastError = null
        eventListener?.invoke(
            mapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "accuracy" to lastAccuracy,
                "capturedAt" to location.time,
                "sessionId" to sessionId
            )
        )
    }

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    override fun onDestroy() {
        removeLocationUpdates()
        running = false
        paused = false
        stateProvider = null
        super.onDestroy()
    }
}

private const val MAX_SEED_AGE_MS = 120000L
private const val PREFERENCES_NAME = "family_location_service"
