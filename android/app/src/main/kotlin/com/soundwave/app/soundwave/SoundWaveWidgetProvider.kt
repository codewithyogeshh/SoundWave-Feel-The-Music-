package com.soundwave.app.soundwave

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import io.flutter.plugin.common.MethodChannel

/**
 * Home screen widget: shows the song that is loaded in SoundWave and lets the
 * user play/pause and skip without opening the app.
 *
 * The widget is drawn with RemoteViews, so the last song stays visible after
 * the app UI is closed. Dart pushes title/artist/play state through the
 * "soundwave/widget" channel, and button taps are sent back to Dart while the
 * playback engine is alive.
 */
class SoundWaveWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS = "sw_widget"
        private const val KEY_TITLE = "title"
        private const val KEY_ARTIST = "artist"
        private const val KEY_PLAYING = "playing"

        const val ACTION_PLAY_PAUSE = "com.soundwave.app.soundwave.WIDGET_PLAY_PAUSE"
        const val ACTION_NEXT = "com.soundwave.app.soundwave.WIDGET_NEXT"
        const val ACTION_PREV = "com.soundwave.app.soundwave.WIDGET_PREV"

        /** Kept for the lifetime of the Flutter engine that hosts playback. */
        private var bridge: MethodChannel? = null

        fun attach(channel: MethodChannel) {
            bridge = channel
        }

        fun update(context: Context, title: String, artist: String, isPlaying: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_TITLE, title)
                .putString(KEY_ARTIST, artist)
                .putBoolean(KEY_PLAYING, isPlaying)
                .apply()
            refresh(context, title, artist, isPlaying)
        }

        private fun refresh(context: Context, title: String, artist: String, isPlaying: Boolean) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(
                ComponentName(context, SoundWaveWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            ids.forEach { id ->
                manager.updateAppWidget(id, buildViews(context, title, artist, isPlaying))
            }
        }

        private fun buildViews(
            context: Context,
            title: String,
            artist: String,
            isPlaying: Boolean,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.soundwave_widget)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_artist, artist)
            views.setImageViewResource(
                R.id.widget_play_pause,
                if (isPlaying) android.R.drawable.ic_media_pause
                else android.R.drawable.ic_media_play,
            )

            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(
                    context,
                    0,
                    Intent(context, MainActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    pendingFlags(),
                ),
            )
            views.setOnClickPendingIntent(
                R.id.widget_prev,
                broadcast(context, ACTION_PREV, 1),
            )
            views.setOnClickPendingIntent(
                R.id.widget_play_pause,
                broadcast(context, ACTION_PLAY_PAUSE, 2),
            )
            views.setOnClickPendingIntent(
                R.id.widget_next,
                broadcast(context, ACTION_NEXT, 3),
            )
            return views
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
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val title = prefs.getString(KEY_TITLE, null) ?: "SoundWave"
        val artist = prefs.getString(KEY_ARTIST, null) ?: "Tap to open"
        val isPlaying = prefs.getBoolean(KEY_PLAYING, false)
        appWidgetIds.forEach { id ->
            appWidgetManager.updateAppWidget(
                id,
                buildViews(context, title, artist, isPlaying),
            )
        }
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
        if (channel != null) {
            channel.invokeMethod("onWidgetAction", command)
        } else {
            // Playback is not running: open the app so the tap does something.
            context.startActivity(
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }
}
