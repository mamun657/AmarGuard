package com.binarypulse.amarguard

import android.content.Intent
import com.binarypulse.amarguard.sharing.SharingServiceChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val EXTRA_OPEN_FAMILY_SAFETY = "open_family_safety"
    }

    private var sharingHandler: SharingServiceChannelHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val handler = SharingServiceChannelHandler { this }
        sharingHandler = handler
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SharingServiceChannelHandler.METHOD_CHANNEL
        ).setMethodCallHandler(handler)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SharingServiceChannelHandler.EVENT_CHANNEL
        ).setStreamHandler(handler)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
