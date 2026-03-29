package com.dealmeida.hike

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.dealmeida.hike/intent"
    }

    private lateinit var channel: MethodChannel

    // Stores file data from a cold-start intent until Dart calls getInitialFile().
    private var pendingFile: HashMap<String, Any>? = null

    override fun attachBaseContext(newBase: Context) {
        val locale = Locale.ENGLISH
        Locale.setDefault(locale)
        val config = newBase.resources.configuration
        config.setLocale(locale)
        super.attachBaseContext(newBase.createConfigurationContext(config))
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cache the engine so HikeAutoService can share it. If Auto started
        // first it already cached an engine — overwrite with this one now that
        // the full UI engine is running.
        FlutterEngineCache.getInstance().put("hike_engine", flutterEngine)

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

        // Cold start: read file from launch intent on an IO thread so the
        // main thread is not blocked by file I/O.
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val fileData = readFileFromIntent(intent)
                withContext(Dispatchers.Main) {
                    pendingFile = fileData
                }
            } catch (e: Exception) {
                Log.e("HikeIntent", "Failed to read intent file", e)
            }
        }
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
        } catch (e: Exception) {
            Log.e("HikeIntent", "Failed to read intent file", e)
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
