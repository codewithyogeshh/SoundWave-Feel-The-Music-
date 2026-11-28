package com.soundwave.app.soundwave

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Shader
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.sin

/**
 * Home screen widget: shows the current song with album art, a progress bar and
 * play/pause/skip controls.
 */
class SoundWaveWidgetProvider : AppWidgetProvider() {

    private data class WidgetState(
        val title: String,
        val artist: String,
        val nextTitle: String?,
        val isPlaying: Boolean,
        val artwork: String?,
        val positionMs: Long,
        val durationMs: Long,
    )

    companion object {
        private const val PREFS = "sw_widget"
        private const val KEY_TITLE = "title"
        private const val KEY_ARTIST = "artist"
        private const val KEY_NEXT_TITLE = "next_title"
        private const val KEY_PLAYING = "playing"
        private const val KEY_ARTWORK = "artwork"
        private const val KEY_POSITION = "position"
        private const val KEY_DURATION = "duration"
        private const val KEY_PENDING = "pending_action"
        private const val KEY_GLOW_PRIMARY = "glow_primary"
        private const val KEY_GLOW_SECONDARY = "glow_secondary"

        /** Violet fallback that matches the app's own accent. */
        private const val DEFAULT_GLOW_PRIMARY = 0xFF8B5CF6.toInt()
        private const val DEFAULT_GLOW_SECONDARY = 0xFF22D3EE.toInt()

        const val ACTION_PLAY_PAUSE = "com.soundwave.app.soundwave.WIDGET_PLAY_PAUSE"
        const val ACTION_NEXT = "com.soundwave.app.soundwave.WIDGET_NEXT"
        const val ACTION_PREV = "com.soundwave.app.soundwave.WIDGET_PREV"

        private const val ART_PIXELS = 288

        private var bridge: MethodChannel? = null
        private var artKey: String? = null
        private var artBitmap: Bitmap? = null
        private val downloading = HashSet<String>()

        fun attach(channel: MethodChannel) {
            bridge = channel
        }

        fun detach(channel: MethodChannel) {
            if (bridge === channel) bridge = null
        }

        fun update(
            context: Context,
            title: String,
            artist: String,
            isPlaying: Boolean,
            artwork: String?,
            nextTitle: String?,
            positionMs: Long,
            durationMs: Long,
        ) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_TITLE, title)
                .putString(KEY_ARTIST, artist)
                .putString(KEY_NEXT_TITLE, nextTitle)
                .putBoolean(KEY_PLAYING, isPlaying)
                .putString(KEY_ARTWORK, artwork)
                .putLong(KEY_POSITION, positionMs)
                .putLong(KEY_DURATION, durationMs)
                .apply()
            refresh(context)
            if (isPlaying) GlowAnimator.start(context) else GlowAnimator.stop(context)
        }

        fun consumePendingAction(context: Context): String? {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val action = prefs.getString(KEY_PENDING, null)
            if (action != null) {
                prefs.edit().remove(KEY_PENDING).apply()
            }
            return action
        }

        private fun rememberPendingAction(context: Context, action: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_PENDING, action)
                .apply()
        }

        private fun readState(context: Context): WidgetState {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return WidgetState(
                title = prefs.getString(KEY_TITLE, null) ?: "SoundWave",
                artist = prefs.getString(KEY_ARTIST, null) ?: "Tap to open",
                nextTitle = prefs.getString(KEY_NEXT_TITLE, null),
                isPlaying = prefs.getBoolean(KEY_PLAYING, false),
                artwork = prefs.getString(KEY_ARTWORK, null),
                positionMs = prefs.getLong(KEY_POSITION, 0L),
                durationMs = prefs.getLong(KEY_DURATION, 0L),
            )
        }

        private fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(
                ComponentName(context, SoundWaveWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val state = readState(context)
            ids.forEach { id ->
                manager.updateAppWidget(id, buildViews(context, state))
            }
            // Keep the glow in step with the song's palette, and with the pulse
            // already running, so a progress refresh never dims the card.
            paintGlow(context, GlowAnimator.phaseNow(), GlowAnimator.beatNow())
        }

        private fun buildViews(context: Context, state: WidgetState): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.soundwave_widget)
            val hasTrack = state.durationMs > 0L
            views.setTextViewText(R.id.widget_title, state.title)
            // A short "Paused" hint makes it obvious why the bar is not moving.
            views.setTextViewText(
                R.id.widget_artist,
                if (hasTrack && !state.isPlaying) "${state.artist} · Paused" else state.artist,
            )
            views.setImageViewResource(
                R.id.widget_play_pause,
                if (state.isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play,
            )

            val duration = state.durationMs.coerceAtLeast(1L)
            val position = state.positionMs.coerceIn(0L, duration)
            views.setProgressBar(
                R.id.widget_progress,
                duration.toInt(),
                position.toInt(),
                false,
            )
            applyArtwork(context, views, state.artwork)

            // Sized to the album above, so the glow frames the cover instead
            // of washing over the whole card.
            val glow = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            views.setInt(
                R.id.widget_glow,
                "setColorFilter",
                glow.getInt(KEY_GLOW_PRIMARY, DEFAULT_GLOW_PRIMARY),
            )
            views.setInt(
                R.id.widget_glow_secondary,
                "setColorFilter",
                glow.getInt(KEY_GLOW_SECONDARY, DEFAULT_GLOW_SECONDARY),
            )

            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(
                    context,
                    0,
                    Intent(context, MainActivity::class.java)
                        .putExtra(MainActivity.EXTRA_ROUTE, "/now-playing")
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    pendingFlags(),
                ),
            )
            views.setOnClickPendingIntent(R.id.widget_prev, broadcast(context, ACTION_PREV, 1))
            views.setOnClickPendingIntent(
                R.id.widget_play_pause,
                broadcast(context, ACTION_PLAY_PAUSE, 2),
            )
            views.setOnClickPendingIntent(R.id.widget_next, broadcast(context, ACTION_NEXT, 3))
            return views
        }

        private fun formatTime(ms: Long): String {
            if (ms <= 0L) return "0:00"
            val totalSeconds = ms / 1000
            val hours = totalSeconds / 3600
            val minutes = (totalSeconds % 3600) / 60
            val seconds = totalSeconds % 60
            val twoDigitSeconds = seconds.toString().padStart(2, '0')
            return if (hours > 0) {
                "$hours:${minutes.toString().padStart(2, '0')}:$twoDigitSeconds"
            } else {
                "$minutes:$twoDigitSeconds"
            }
        }

        private fun applyArtwork(context: Context, views: RemoteViews, artwork: String?) {
            val key = artwork?.trim().orEmpty()
            if (key.isEmpty()) {
                views.setImageViewResource(R.id.widget_art, R.drawable.widget_art_placeholder)
                return
            }
            if (key == artKey) {
                val cached = artBitmap
                if (cached != null) {
                    views.setImageViewBitmap(R.id.widget_art, cached)
                    return
                }
            }

            if (key.startsWith("http://") || key.startsWith("https://")) {
                val file = artCacheFile(context, key)
                if (file.exists()) {
                    val bitmap = decodeRounded(file)
                    if (bitmap != null) {
                        showArt(context, views, key, bitmap)
                        return
                    }
                }
                views.setImageViewResource(R.id.widget_art, R.drawable.widget_art_placeholder)
                downloadArtwork(context, key)
                return
            }

            if (key.startsWith("assets/") || key.startsWith("asset://")) {
                views.setImageViewResource(R.id.widget_art, R.drawable.widget_art_placeholder)
                return
            }

            val bitmap = when {
                key.startsWith("content://") -> decodeContent(context, key)
                key.startsWith("file://") -> {
                    val path = Uri.parse(key).path
                    if (path.isNullOrEmpty()) null else decodeRounded(File(path))
                }
                else -> decodeRounded(File(key))
            }
            if (bitmap != null) {
                showArt(context, views, key, bitmap)
            } else {
                views.setImageViewResource(R.id.widget_art, R.drawable.widget_art_placeholder)
            }
        }

        /** Shows a decoded cover and remembers its colours for the beat glow. */
        private fun showArt(
            context: Context,
            views: RemoteViews,
            key: String,
            bitmap: Bitmap,
        ) {
            artKey = key
            artBitmap = bitmap
            views.setImageViewBitmap(R.id.widget_art, bitmap)
            rememberPalette(context, bitmap)
        }

        private fun rememberPalette(context: Context, bitmap: Bitmap) {
            val (primary, secondary) = paletteFrom(bitmap)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putInt(KEY_GLOW_PRIMARY, primary)
                .putInt(KEY_GLOW_SECONDARY, secondary)
                .apply()
        }

        /**
         * The two most present colourful hues in the cover, so every song glows
         * in its own colours. A grey/brown sleeve falls back to the app accent.
         */
        private fun paletteFrom(bitmap: Bitmap): Pair<Int, Int> {
            val hsv = FloatArray(3)
            val bins = FloatArray(24)
            val stepX = (bitmap.width / 40).coerceAtLeast(1)
            val stepY = (bitmap.height / 40).coerceAtLeast(1)
            var x = 0
            while (x < bitmap.width) {
                var y = 0
                while (y < bitmap.height) {
                    Color.colorToHSV(bitmap.getPixel(x, y), hsv)
                    if (hsv[1] > 0.2f && hsv[2] > 0.2f) {
                        val bin = (hsv[0] / 15f).toInt().coerceIn(0, 23)
                        bins[bin] += hsv[1] * hsv[2]
                    }
                    y += stepY
                }
                x += stepX
            }

            var best = -1
            for (i in bins.indices) {
                if (bins[i] > 0f && (best < 0 || bins[i] > bins[best])) best = i
            }
            if (best < 0) return DEFAULT_GLOW_PRIMARY to DEFAULT_GLOW_SECONDARY

            val hue = (best * 15f + 7.5f) % 360f
            val primary = Color.HSVToColor(floatArrayOf(hue, 0.72f, 1f))
            val secondary = Color.HSVToColor(floatArrayOf((hue + 62f) % 360f, 0.55f, 1f))
            return primary to secondary
        }

        private fun artCacheFile(context: Context, url: String): File {
            val dir = File(context.cacheDir, "widget_art")
            if (!dir.exists()) dir.mkdirs()
            return File(dir, Integer.toHexString(url.hashCode()) + ".img")
        }

        private fun downloadArtwork(context: Context, url: String) {
            synchronized(downloading) {
                if (!downloading.add(url)) return
            }
            Thread {
                var connection: HttpURLConnection? = null
                try {
                    connection = (URL(url).openConnection() as HttpURLConnection).apply {
                        connectTimeout = 8000
                        readTimeout = 8000
                        instanceFollowRedirects = true
                    }
                    if (connection.responseCode !in 200..299) return@Thread
                    val target = artCacheFile(context, url)
                    connection.inputStream.use { input ->
                        FileOutputStream(target).use { output -> input.copyTo(output) }
                    }
                    Handler(Looper.getMainLooper()).post {
                        artKey = null
                        artBitmap = null
                        refresh(context)
                    }
                } catch (_: Exception) {
                    // Keep the placeholder; the next song change tries again.
                } finally {
                    connection?.disconnect()
                    synchronized(downloading) { downloading.remove(url) }
                }
            }.start()
        }

        private fun decodeRounded(file: File): Bitmap? {
            if (!file.exists() || file.length() == 0L) return null
            return try {
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(file.absolutePath, bounds)
                if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
                val options = BitmapFactory.Options().apply {
                    inSampleSize = sampleSize(bounds.outWidth, bounds.outHeight)
                }
                val decoded = BitmapFactory.decodeFile(file.absolutePath, options) ?: return null
                roundAndSquare(decoded)
            } catch (_: Exception) {
                null
            }
        }

        private fun decodeContent(context: Context, uri: String): Bitmap? {
            return try {
                context.contentResolver.openInputStream(Uri.parse(uri))?.use { input ->
                    val decoded = BitmapFactory.decodeStream(input) ?: return null
                    roundAndSquare(decoded)
                }
            } catch (_: Exception) {
                null
            }
        }

        private fun sampleSize(width: Int, height: Int): Int {
            var sample = 1
            while (minOf(width, height) / sample > ART_PIXELS * 2) {
                sample *= 2
            }
            return sample
        }

        private fun roundAndSquare(source: Bitmap): Bitmap {
            val side = minOf(source.width, source.height)
            val cropped = Bitmap.createBitmap(
                source,
                (source.width - side) / 2,
                (source.height - side) / 2,
                side,
                side,
            )
            val size = minOf(side, ART_PIXELS)
            val scaled =
                if (cropped.width == size) cropped
                else Bitmap.createScaledBitmap(cropped, size, size, true)

            val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(output)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.shader = BitmapShader(scaled, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
            // A true circle, so the cover reads as a round sleeve in the widget.
            val centre = size / 2f
            canvas.drawCircle(centre, centre, centre, paint)
            return output
        }

        /**
         * Draws one glow frame. [phase] is the beat position (0..1); a negative
         * phase means "settled", used while paused so the card keeps a soft
         * colour without pulsing.
         */
        fun paintGlow(context: Context, phase: Float, beat: Int) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(
                ComponentName(context, SoundWaveWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return

            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val primary = prefs.getInt(KEY_GLOW_PRIMARY, DEFAULT_GLOW_PRIMARY)
            val secondary = prefs.getInt(KEY_GLOW_SECONDARY, DEFAULT_GLOW_SECONDARY)
            val live = phase >= 0f
            // Sharp attack and a soft fall: reads as a beat, not a sine wave.
            val wave = max(0f, sin(phase.toDouble() * 2.0 * PI).toFloat())
            val pulse = if (live) wave * wave * wave else 0f
            val leading = if (!live || beat % 2 == 0) primary else secondary
            val trailing = if (!live || beat % 2 == 0) secondary else primary

            val views = RemoteViews(context.packageName, R.layout.soundwave_widget)
            views.setInt(R.id.widget_glow, "setColorFilter", leading)
            views.setFloat(R.id.widget_glow, "setAlpha", 0.2f + 0.55f * pulse)
            views.setInt(R.id.widget_glow_secondary, "setColorFilter", trailing)
            views.setFloat(R.id.widget_glow_secondary, "setAlpha", 0.14f + 0.4f * pulse)
            try {
                manager.partiallyUpdateAppWidget(ids, views)
            } catch (_: Exception) {
                // A launcher that rejects partial updates keeps the last frame.
            }
        }

        private fun broadcast(context: Context, action: String, requestCode: Int): PendingIntent {
            val intent = Intent(context, SoundWaveWidgetProvider::class.java).setAction(action)
            return PendingIntent.getBroadcast(context, requestCode, intent, pendingFlags())
        }

        private fun pendingFlags(): Int {
            val immutable =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE
                else 0
            return PendingIntent.FLAG_UPDATE_CURRENT or immutable
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val state = readState(context)
        appWidgetIds.forEach { id ->
            appWidgetManager.updateAppWidget(id, buildViews(context, state))
        }
        if (state.isPlaying) GlowAnimator.start(context) else GlowAnimator.stop(context)
    }

    override fun onDisabled(context: Context) {
        GlowAnimator.stop(context)
        super.onDisabled(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val command = when (intent.action) {
            ACTION_PLAY_PAUSE -> "playPause"
            ACTION_NEXT -> "next"
            ACTION_PREV -> "prev"
            else -> return
        }
        val channel = bridge
        if (channel == null) {
            openAppWithAction(context, command)
            return
        }
        channel.invokeMethod(
            "onWidgetAction",
            command,
            object : MethodChannel.Result {
                override fun success(result: Any?) = Unit
                override fun error(code: String, message: String?, details: Any?) {
                    openAppWithAction(context, command)
                }

                override fun notImplemented() {
                    openAppWithAction(context, command)
                }
            },
        )
    }

    private fun openAppWithAction(context: Context, command: String) {
        rememberPendingAction(context, command)
        context.startActivity(
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}

/**
 * Pulses the widget's glow in time with the music.
 *
 * It only ticks while a track is actually playing, and the audio service keeps
 * this process alive in the background, so a paused or closed app costs nothing
 * and the widget simply keeps its last, settled glow.
 */
private object GlowAnimator {
    private val handler = Handler(Looper.getMainLooper())
    private const val INTERVAL_MS = 120L

    /** A little under two beats a second — the pulse most songs share. */
    private const val BEAT_MS = 520f

    private var running = false
    private var phase = 0f
    private var beat = 0
    private var appContext: Context? = null

    private val ticker = object : Runnable {
        override fun run() {
            if (!running) return
            val context = appContext ?: return
            phase += INTERVAL_MS / BEAT_MS
            if (phase >= 1f) {
                phase -= 1f
                beat++
            }
            SoundWaveWidgetProvider.paintGlow(context, phase, beat)
            handler.postDelayed(this, INTERVAL_MS)
        }
    }

    /** The live pulse position, or -1 when the glow should sit still. */
    fun phaseNow(): Float = if (running) phase else -1f

    fun beatNow(): Int = beat

    fun start(context: Context) {
        appContext = context.applicationContext
        if (running) return
        running = true
        handler.removeCallbacks(ticker)
        handler.post(ticker)
    }

    fun stop(context: Context) {
        if (!running) return
        running = false
        handler.removeCallbacks(ticker)
        val app = context.applicationContext
        SoundWaveWidgetProvider.paintGlow(app, -1f, 0)
    }
}
