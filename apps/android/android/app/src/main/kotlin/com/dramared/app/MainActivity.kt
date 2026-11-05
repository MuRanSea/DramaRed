package com.dramared.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.dramared.app/smoke"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSmokeArgs" -> {
                        val extras = intent?.extras
                        result.success(
                            mapOf(
                                "auto" to (extras?.getBoolean("smoke_auto", false) ?: false),
                                "query" to (extras?.getString("smoke_query") ?: ""),
                                "seconds" to (extras?.getInt("smoke_seconds", 20) ?: 20),
                                "url" to (extras?.getString("smoke_url") ?: ""),
                            ),
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
