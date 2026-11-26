package com.soundwave.app.soundwave

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
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
    }

    override fun onDestroy() {
        widgetChannel?.let { SoundWaveWidgetProvider.detach(it) }
        widgetChannel = null
        super.onDestroy()
    }
}
