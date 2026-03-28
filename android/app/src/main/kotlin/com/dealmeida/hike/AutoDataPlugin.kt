package com.dealmeida.hike

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AutoDataPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.dealmeida.hike/auto_data")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "update") {
            val args = call.arguments as? Map<*, *>
            HikeCarScreen.updateData(
                lat = (args?.get("lat") as? Double) ?: 0.0,
                lon = (args?.get("lon") as? Double) ?: 0.0,
                alt = (args?.get("alt") as? Double) ?: 0.0,
                heading = (args?.get("heading") as? Double) ?: -1.0,
                hasPosition = (args?.get("hasPosition") as? Boolean) ?: false,
            )
            result.success(null)
        } else {
            result.notImplemented()
        }
    }
}
