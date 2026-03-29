package com.dealmeida.hike

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.dealmeida.hike/intent"
    }

    private lateinit var channel: MethodChannel

    // Stores file data from a cold-start intent until Dart calls getInitialFile().
    private var pendingFile: HashMap<String, Any>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            if (call.method == "getInitialFile") {
                result.success(pendingFile)
                pendingFile = null
            } else {
                result.notImplemented()
            }
        }

        flutterEngine.plugins.add(AutoDataPlugin())

        // Cold start: store any file carried by the launch intent.
        // Flutter is not yet running here, so we cannot invokeMethod yet.
        pendingFile = readFileFromIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Warm start: Flutter is already running — push the file directly.
        val fileData = readFileFromIntent(intent) ?: return
        channel.invokeMethod("onNewFile", fileData)
    }

    private fun readFileFromIntent(intent: Intent?): HashMap<String, Any>? {
        val uri: Uri = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        } ?: return null

        return try {
            val stream = contentResolver.openInputStream(uri) ?: return null
            val bytes = stream.readBytes()
            stream.close()
            hashMapOf("bytes" to bytes, "filename" to (resolveFilename(uri) ?: "trail.gpx"))
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveFilename(uri: Uri): String? {
        if (uri.scheme == "content") {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val col = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (col >= 0) return cursor.getString(col)
                }
            }
        }
        return uri.lastPathSegment
    }
}
