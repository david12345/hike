package com.dealmeida.hike

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.util.LruCache
import androidx.car.app.CarContext
import androidx.car.app.SurfaceContainer
import java.net.URL
import java.util.concurrent.Executors
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.ln
import kotlin.math.tan

/// Fetches OpenStreetMap tiles over HTTP with an in-process LruCache and
/// draws them onto the Android Auto [SurfaceContainer] surface.
///
/// A 3x3 grid of tiles is rendered at zoom level 15, centred on the current
/// GPS position. A blue dot marks the exact centre of the surface.
///
/// All tile fetching is off-loaded to a single-thread executor to keep the
/// render callback non-blocking. Drawing uses [Surface.lockHardwareCanvas] /
/// [Surface.unlockCanvasAndPost].
class AutoTileRenderer(@Suppress("UnusedPrivateMember") private val carContext: CarContext) {

    private var surfaceContainer: SurfaceContainer? = null
    private var visibleArea: Rect? = null
    private var centerLat = 0.0
    private var centerLon = 0.0
    private val zoom = 15
    private val tileSize = 256

    private val executor = Executors.newSingleThreadExecutor()

    private val tileCache = object : LruCache<String, Bitmap>(50) {
        override fun entryRemoved(
            evicted: Boolean,
            key: String,
            oldValue: Bitmap,
            newValue: Bitmap?,
        ) {
            if (evicted) oldValue.recycle()
        }
    }

    private val dotPaint = Paint().apply {
        color = Color.BLUE
        style = Paint.Style.FILL
        isAntiAlias = true
    }

    private val bgPaint = Paint().apply {
        color = Color.DKGRAY
        style = Paint.Style.FILL
    }

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    fun updatePosition(lat: Double, lon: Double) {
        centerLat = lat
        centerLon = lon
        redraw()
    }

    fun onSurfaceAvailable(container: SurfaceContainer) {
        surfaceContainer = container
        redraw()
    }

    fun onSurfaceDestroyed() {
        surfaceContainer = null
    }

    fun onVisibleAreaChanged(area: Rect) {
        visibleArea = area
        redraw()
    }

    // -------------------------------------------------------------------------
    // Tile math
    // -------------------------------------------------------------------------

    private fun lonToTileX(lon: Double, z: Int): Int =
        floor((lon + 180.0) / 360.0 * (1 shl z)).toInt()

    private fun latToTileY(lat: Double, z: Int): Int {
        val latRad = Math.toRadians(lat)
        return floor(
            (1.0 - ln(tan(latRad) + 1.0 / cos(latRad)) / PI) / 2.0 * (1 shl z)
        ).toInt()
    }

    // -------------------------------------------------------------------------
    // Render logic
    // -------------------------------------------------------------------------

    private fun redraw() {
        val container = surfaceContainer ?: return
        val w = container.width
        val h = container.height
        if (w <= 0 || h <= 0) return
        if (centerLat == 0.0 && centerLon == 0.0) return

        val cx = lonToTileX(centerLon, zoom)
        val cy = latToTileY(centerLat, zoom)

        // Fetch missing tiles on the background thread, then draw.
        executor.submit {
            for (dx in -1..1) {
                for (dy in -1..1) {
                    val key = "$zoom/${cx + dx}/${cy + dy}"
                    if (tileCache[key] == null) {
                        fetchTile(zoom, cx + dx, cy + dy)?.let { bmp ->
                            tileCache.put(key, bmp)
                        }
                    }
                }
            }
            drawFrame(container, w, h, cx, cy)
        }
    }

    private fun drawFrame(container: SurfaceContainer, w: Int, h: Int, cx: Int, cy: Int) {
        val surface = container.surface ?: return
        val canvas: Canvas = try {
            surface.lockHardwareCanvas()
        } catch (e: Exception) {
            return
        }
        try {
            // Background fill in case some tiles are missing.
            canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), bgPaint)

            // Offset so that the centre tile is centred on the surface.
            val offX = w / 2 - tileSize / 2
            val offY = h / 2 - tileSize / 2

            for (dx in -1..1) {
                for (dy in -1..1) {
                    val key = "$zoom/${cx + dx}/${cy + dy}"
                    val bitmap = tileCache[key] ?: continue
                    canvas.drawBitmap(
                        bitmap,
                        (offX + dx * tileSize).toFloat(),
                        (offY + dy * tileSize).toFloat(),
                        null,
                    )
                }
            }

            // Blue dot at the centre of the surface marks current position.
            canvas.drawCircle(w / 2f, h / 2f, 18f, dotPaint)
        } finally {
            surface.unlockCanvasAndPost(canvas)
        }
    }

    // -------------------------------------------------------------------------
    // Tile fetching
    // -------------------------------------------------------------------------

    private fun fetchTile(z: Int, x: Int, y: Int): Bitmap? = try {
        val url = URL("https://tile.openstreetmap.org/$z/$x/$y.png")
        val conn = url.openConnection()
        conn.setRequestProperty(
            "User-Agent",
            "Hike/1.0 (+https://github.com/david12345/hike)",
        )
        conn.connectTimeout = 5_000
        conn.readTimeout = 5_000
        conn.getInputStream().use { stream ->
            BitmapFactory.decodeStream(stream)
        }
    } catch (e: Exception) {
        null
    }
}
