package io.github.stamasg84.mondom

import android.content.ActivityNotFoundException
import android.content.Context
import android.app.Activity
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.provider.Settings
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

class MainActivity : FlutterActivity() {
    private companion object {
        const val REQUEST_SAVE = 4301
        const val REQUEST_PICK = 4302
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.stamasg84.mondom/tts"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openInstallVoiceData" -> result.success(openInstallVoiceData())
                "availability" -> availability(call.arguments.toString(), result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "mondom/alarm_volume"
        ).setMethodCallHandler { call, result -> alarmVolume(call, result) }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "mondom/app_settings"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> result.success(openAppSettings())
                "openUrl" -> result.success(openUrl(call.arguments?.toString()))
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "mondom/backup"
        ).setMethodCallHandler { call, result -> backup(call, result) }
    }

    private var backupResult: MethodChannel.Result? = null
    private var backupPath: String? = null

    /**
     * `save(source, name)`: the system "save as" screen, then streams the file
     * there. `pick(dest)`: the system file picker, then streams the chosen
     * file to [dest]. Both answer true, or false when cancelled. No storage
     * permission is needed; Drive etc. show up in the picker by themselves.
     */
    private fun backup(call: MethodCall, result: MethodChannel.Result) {
        if (backupResult != null) {
            result.error("busy", "A file picker is already open", null)
            return
        }
        try {
            val intent: Intent
            val code: Int
            when (call.method) {
                "save" -> {
                    backupPath = call.argument<String>("source")
                    intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/zip"
                        putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                    }
                    code = REQUEST_SAVE
                }
                "pick" -> {
                    backupPath = call.argument<String>("dest")
                    intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                    }
                    code = REQUEST_PICK
                }
                else -> {
                    result.notImplemented()
                    return
                }
            }
            backupResult = result
            startActivityForResult(intent, code)
        } catch (e: Exception) {
            backupResult = null
            result.error("backup", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_SAVE && requestCode != REQUEST_PICK) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = backupResult ?: return
        val path = backupPath
        backupResult = null
        backupPath = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || path == null) {
            result.success(false)
            return
        }
        // The zip may be 100 MB+: copy off the main thread, in chunks.
        Thread {
            try {
                if (requestCode == REQUEST_SAVE) {
                    contentResolver.openOutputStream(uri, "w")!!.use { out ->
                        File(path).inputStream().use { it.copyTo(out) }
                    }
                } else {
                    contentResolver.openInputStream(uri)!!.use { input ->
                        File(path).outputStream().use { input.copyTo(it) }
                    }
                }
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.error("copy", e.message, null) }
            }
        }.start()
    }

    /** Opens [url] in the browser; false when nothing can handle it. */
    private fun openUrl(url: String?): Boolean {
        if (url.isNullOrEmpty()) return false
        return try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    /** Opens this app's page in Android settings (to re-allow the microphone). */
    private fun openAppSettings(): Boolean {
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", packageName, null)
                )
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    /** `get` → {current, max} of STREAM_ALARM; `set(level)` sets it silently. */
    private fun alarmVolume(call: MethodCall, result: MethodChannel.Result) {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        try {
            when (call.method) {
                "get" -> result.success(
                    mapOf(
                        "current" to audio.getStreamVolume(AudioManager.STREAM_ALARM),
                        "max" to audio.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                    )
                )
                "set" -> {
                    val level = call.arguments as Int
                    audio.setStreamVolume(AudioManager.STREAM_ALARM, level, 0)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("volume", e.message, null)
        }
    }

    /**
     * "installed" | "missingData" | "unsupported" for a language code ("hu").
     * Matches voices by language only: flutter_tts compares whole locales
     * ("hu" != "hu_HU"), which never matches real voices.
     */
    private fun availability(language: String, result: MethodChannel.Result) {
        var tts: TextToSpeech? = null
        tts = TextToSpeech(applicationContext) { status ->
            val engine = tts
            if (status != TextToSpeech.SUCCESS || engine == null) {
                result.error("init", "TTS init failed: $status", null)
                engine?.shutdown()
                return@TextToSpeech
            }
            try {
                val avail = engine.isLanguageAvailable(Locale(language))
                val voices = (engine.voices ?: emptySet()).filter {
                    it.locale.language == language
                }
                val usable = voices.any {
                    !it.isNetworkConnectionRequired &&
                        !it.features.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED)
                }
                val answer = when {
                    usable -> "installed"
                    // Engine lists no voices at all: trust isLanguageAvailable.
                    (engine.voices ?: emptySet()).isEmpty() ->
                        if (avail >= TextToSpeech.LANG_AVAILABLE) "installed" else "unsupported"
                    voices.isNotEmpty() || avail == TextToSpeech.LANG_MISSING_DATA ||
                        avail >= TextToSpeech.LANG_AVAILABLE -> "missingData"
                    else -> "unsupported"
                }
                result.success(answer)
            } catch (e: Exception) {
                result.error("query", e.message, null)
            } finally {
                engine.shutdown()
            }
        }
    }

    /** Engine's voice-data install screen; falls back to the TTS settings. */
    private fun openInstallVoiceData(): Boolean {
        val intents = listOf(
            Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA),
            Intent("com.android.settings.TTS_SETTINGS"),
        )
        for (intent in intents) {
            try {
                startActivity(intent)
                return true
            } catch (e: ActivityNotFoundException) {
                // Try the next one.
            } catch (e: SecurityException) {
                // Try the next one.
            }
        }
        return false
    }
}
