package com.dramared.app

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val smokeChannel = "com.dramared.app/smoke"
    private val coverChannel = "com.dramared.app/covers"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, smokeChannel)
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

        // OHG posters are often image/heic; Flutter Image.network cannot decode them.
        // Android BitmapFactory supports HEIF from API 28+.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, coverChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "decodeToPng" -> {
                        val bytes = call.arguments as? ByteArray
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("bad_args", "expected non-empty byte[]", null)
                            return@setMethodCallHandler
                        }
                        if (Build.VERSION.SDK_INT < 28) {
                            result.error("unsupported", "HEIF decode needs API 28+", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                            if (bmp == null) {
                                result.error("decode_failed", "BitmapFactory returned null", null)
                                return@setMethodCallHandler
                            }
                            val out = ByteArrayOutputStream()
                            bmp.compress(Bitmap.CompressFormat.PNG, 90, out)
                            if (!bmp.isRecycled) bmp.recycle()
                            result.success(out.toByteArray())
                        } catch (e: Exception) {
                            result.error("decode_failed", e.message, null)
                        }
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
