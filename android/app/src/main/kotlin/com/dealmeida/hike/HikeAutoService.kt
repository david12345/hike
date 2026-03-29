package com.dealmeida.hike

import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class HikeAutoService : CarAppService() {

    override fun createHostValidator(): HostValidator =
        HostValidator.ALLOW_ALL_HOSTS_VALIDATOR

    override fun onCreate() {
        super.onCreate()
        val cache = FlutterEngineCache.getInstance()
        if (!cache.contains("hike_engine")) {
            // Android Auto bound before MainActivity was opened — spin up a
            // dedicated Flutter engine so the MethodChannel is available.
            val engine = FlutterEngine(this)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            engine.plugins.add(AutoDataPlugin())
            cache.put("hike_engine", engine)
        } else {
            // Engine already running (MainActivity opened first) — just make
            // sure AutoDataPlugin is registered against it.
            val engine = cache["hike_engine"]!!
            // Registering twice is a no-op if the plugin is already present.
            runCatching { engine.plugins.add(AutoDataPlugin()) }
        }
    }

    override fun onCreateSession(): Session = HikeCarSession()
}
