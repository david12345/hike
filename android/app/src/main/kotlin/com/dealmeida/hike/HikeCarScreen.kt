package com.dealmeida.hike

import android.graphics.Rect
import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.NavigationTemplate
import kotlin.math.roundToInt

class HikeCarScreen(carContext: CarContext) : Screen(carContext), SurfaceCallback {

    private val renderer = AutoTileRenderer(carContext)

    companion object {
        @Volatile private var currentInstance: HikeCarScreen? = null

        @Volatile private var lat = 0.0
        @Volatile private var lon = 0.0
        @Volatile private var alt = 0.0
        @Volatile private var heading = -1.0
        @Volatile private var hasPosition = false

        fun updateData(
            lat: Double,
            lon: Double,
            alt: Double,
            heading: Double,
            hasPosition: Boolean,
        ) {
            this.lat = lat
            this.lon = lon
            this.alt = alt
            this.heading = heading
            this.hasPosition = hasPosition
            currentInstance?.let { screen ->
                screen.renderer.updatePosition(lat, lon)
                screen.invalidate()
            }
        }
    }

    init {
        currentInstance = this
        // Register this screen as the SurfaceCallback so the Car App Library
        // delivers surface lifecycle events to us.
        carContext.getCarService(AppManager::class.java).setSurfaceCallback(this)
    }

    override fun onGetTemplate(): Template {
        val actionStrip = ActionStrip.Builder()
            .addAction(
                Action.Builder()
                    .setTitle(formatHeading(heading))
                    .setOnClickListener {}
                    .build()
            )
            .addAction(
                Action.Builder()
                    .setTitle(if (hasPosition) "LAT ${String.format("%.4f", lat)}" else "LAT --")
                    .setOnClickListener {}
                    .build()
            )
            .addAction(
                Action.Builder()
                    .setTitle(if (hasPosition) "LON ${String.format("%.4f", lon)}" else "LON --")
                    .setOnClickListener {}
                    .build()
            )
            .addAction(
                Action.Builder()
                    .setTitle(if (hasPosition) "ALT ${alt.roundToInt()} m" else "ALT --")
                    .setOnClickListener {}
                    .build()
            )
            .build()

        return NavigationTemplate.Builder()
            .setActionStrip(actionStrip)
            .setMapActionStrip(
                ActionStrip.Builder()
                    .addAction(Action.PAN)
                    .build()
            )
            .build()
    }

    private fun formatHeading(h: Double): String {
        if (h < 0) return "N/A"
        val cardinals = arrayOf("N", "NE", "E", "SE", "S", "SW", "W", "NW")
        val cardinal = cardinals[((h + 22.5) / 45.0).toInt() % 8]
        return "$cardinal ${h.roundToInt()}\u00B0"
    }

    // -------------------------------------------------------------------------
    // SurfaceCallback
    // -------------------------------------------------------------------------

    override fun onSurfaceAvailable(surfaceContainer: SurfaceContainer) {
        renderer.onSurfaceAvailable(surfaceContainer)
    }

    override fun onSurfaceDestroyed(surfaceContainer: SurfaceContainer) {
        renderer.onSurfaceDestroyed()
        currentInstance = null
    }

    override fun onVisibleAreaChanged(visibleArea: Rect) {
        renderer.onVisibleAreaChanged(visibleArea)
    }
}
