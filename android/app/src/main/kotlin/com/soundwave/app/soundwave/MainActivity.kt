package com.soundwave.app.soundwave

import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : AudioServiceActivity() {
    private var widgetChannel: MethodChannel? = null

    companion object {
        /** Set when the widget is tapped, so the app can open the player screen. */
        const val EXTRA_ROUTE = "com.soundwave.app.soundwave.ROUTE"

        private var pendingRoute: String? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingRoute = intent?.getStringExtra(EXTRA_ROUTE) ?: pendingRoute
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val route = intent.getStringExtra(EXTRA_ROUTE) ?: return
        intent.removeExtra(EXTRA_ROUTE)
        pendingRoute = route
        // Already running: let the Flutter side navigate right away.
        widgetChannel?.invokeMethod("onWidgetAction", "openPlayer", null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Used by the home screen widget: Dart pushes the current song and
        // receives play/pause/skip taps from the widget buttons.
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "soundwave/widget",
        )
        widgetChannel = channel
        SoundWaveWidgetProvider.attach(channel)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    val title = call.argument<String>("title") ?: "SoundWave"
                    val artist = call.argument<String>("artist") ?: "Tap to open"
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    val artwork = call.argument<String>("artwork")
                    val nextTitle = call.argument<String>("nextTitle")
                    val positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
                    val durationMs = call.argument<Number>("durationMs")?.toLong() ?: 0L
                    SoundWaveWidgetProvider.update(
                        this,
                        title,
                        artist,
                        isPlaying,
                        artwork,
                        nextTitle,
                        positionMs,
                        durationMs,
                    )
                    result.success(true)
                }

                // A widget tap asked for a specific screen (e.g. the player).
                "consumePendingRoute" -> {
                    val route = pendingRoute
                    pendingRoute = null
                    intent?.removeExtra(EXTRA_ROUTE)
                    result.success(route)
                }

                // Taps that arrived while the app was closed are replayed now.
                "consumePendingAction" -> {
                    result.success(SoundWaveWidgetProvider.consumePendingAction(this))
                }

                else -> result.notImplemented()
            }
        }

        // Used by the in-app updater: the Dart side downloads the APK and asks
        // Android to install it, so no browser or file manager is involved.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "soundwave/installer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        val apk = if (path.isNullOrEmpty()) null else File(path)
                        if (apk == null || !apk.exists()) {
                            result.error("missing_apk", "The downloaded APK could not be found.", null)
                            return@setMethodCallHandler
                        }

                        // Android 8+ needs the user to allow this app to install
                        // packages; open that settings screen and let the app
                        // ask the user to tap Update again.
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            !packageManager.canRequestPackageInstalls()
                        ) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName"),
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                            )
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        try {
                            val uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                apk,
                            )
                            startActivity(
                                Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(
                                        uri,
                                        "application/vnd.android.package-archive",
                                    )
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                },
                            )
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("install_failed", error.message, null)
                        }
                    }

                    // Used by "Share SoundWave": Android stores the installed
                    // package as base.apk, so copy it to the cache with a
                    // friendly name before handing it to the share sheet.
                    "shareApk" -> Thread {
                        try {
                            val versionName = packageManager
                                .getPackageInfo(packageName, 0)
                                .versionName ?: "1.0"

                            val sharesDir = File(cacheDir, "shares")
                            sharesDir.listFiles()?.forEach { it.delete() }
                            sharesDir.mkdirs()

                            val target = File(sharesDir, "SoundWave-v$versionName.apk")
                            File(applicationInfo.sourceDir).inputStream().use { input ->
                                FileOutputStream(target).use { output -> input.copyTo(output) }
                            }

                            val uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                target,
                            )
                            val share = Intent(Intent.ACTION_SEND).apply {
                                type = "application/vnd.android.package-archive"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                putExtra(Intent.EXTRA_SUBJECT, "SoundWave v$versionName")
                                putExtra(
                                    Intent.EXTRA_TEXT,
                                    "SoundWave — feel the music, live the moment.",
                                )
                                clipData = ClipData.newRawUri("SoundWave APK", uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }

                            runOnUiThread {
                                startActivity(
                                    Intent.createChooser(share, "Share SoundWave")
                                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                                )
                                result.success(target.path)
                            }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error("share_failed", error.message, null)
                            }
                        }
                    }.start()

                    else -> result.notImplemented()
                }
            }

        // Used when Downloads are set to "Phone storage": the song lands in the
        // shared Music/SoundWave folder and stays playable inside SoundWave.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "soundwave/media_store")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToMusic" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name")
                        val mime = call.argument<String>("mime") ?: "audio/mp4"
                        val source = if (path.isNullOrEmpty()) null else File(path)
                        if (source == null || !source.exists() || name.isNullOrEmpty()) {
                            result.error(
                                "missing_file",
                                "The downloaded song could not be found.",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val saved = saveToMusic(source, name, mime)
                                runOnUiThread { result.success(saved) }
                            } catch (error: SecurityException) {
                                runOnUiThread {
                                    result.error("permission_denied", error.message, null)
                                }
                            } catch (error: Exception) {
                                runOnUiThread {
                                    result.error("save_failed", error.message, null)
                                }
                            }
                        }.start()
                    }

                    "deleteSaved" -> Thread {
                        try {
                            val removed = deleteSavedMusic(
                                call.argument<String>("uri"),
                                call.argument<String>("path"),
                            )
                            runOnUiThread { result.success(removed) }
                        } catch (error: Exception) {
                            runOnUiThread { result.success(false) }
                        }
                    }.start()

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Copies a finished download into the phone's shared Music/SoundWave folder.
     *
     * Android 10+ owns that folder through MediaStore, so the app can add a song
     * there without asking for the heavy "All files access" permission. Older
     * releases still write the file directly.
     */
    private fun saveToMusic(source: File, displayName: String, mime: String): Map<String, Any?> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = contentResolver
            val collection = MediaStore.Audio.Media.getContentUri(
                MediaStore.VOLUME_EXTERNAL_PRIMARY,
            )
            val values = ContentValues().apply {
                put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
                put(MediaStore.Audio.Media.MIME_TYPE, mime)
                put(
                    MediaStore.Audio.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_MUSIC + "/SoundWave",
                )
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            }
            val uri = resolver.insert(collection, values)
                ?: throw IllegalStateException("The Music folder refused the new song")
            try {
                resolver.openOutputStream(uri)?.use { output ->
                    source.inputStream().use { input -> input.copyTo(output) }
                } ?: throw IllegalStateException("Could not open the new song file")
                val publish = ContentValues().apply {
                    put(MediaStore.Audio.Media.IS_PENDING, 0)
                }
                resolver.update(uri, publish, null, null)
            } catch (error: Exception) {
                try {
                    resolver.delete(uri, null, null)
                } catch (_: Exception) {
                }
                throw error
            }
            return mapOf("uri" to uri.toString(), "path" to null)
        }

        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC),
            "SoundWave",
        )
        if (!dir.exists() && !dir.mkdirs()) {
            throw IllegalStateException("Could not create the Music/SoundWave folder")
        }
        val target = File(dir, displayName)
        source.inputStream().use { input ->
            FileOutputStream(target).use { output -> input.copyTo(output) }
        }
        return mapOf("uri" to null, "path" to target.absolutePath)
    }

    /** Removes a song this app added to the shared Music folder. */
    private fun deleteSavedMusic(uriString: String?, path: String?): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !uriString.isNullOrEmpty()) {
            return contentResolver.delete(Uri.parse(uriString), null, null) > 0
        }
        if (!path.isNullOrEmpty()) {
            val file = File(path)
            return file.exists() && file.delete()
        }
        return false
    }

    override fun onDestroy() {
        widgetChannel?.let { SoundWaveWidgetProvider.detach(it) }
        widgetChannel = null
        super.onDestroy()
    }
}
