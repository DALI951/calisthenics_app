package com.dali951.calisthenics_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hands a downloaded APK to the system installer.
 *
 * Flutter's `url_launcher` cannot express an Android installer intent: it has
 * no way to set the APK MIME type, and — critically — no way to add
 * `FLAG_GRANT_READ_URI_PERMISSION`. Without that grant the installer cannot
 * read the file and the update dies with "App not installed" before it starts.
 * That is a platform fact, so it lives here rather than in Dart.
 */
class UpdateInstallerChannel(private val context: android.content.Context) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.dali951.calisthenics_app/update_installer"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "installApk") {
            result.notImplemented()
            return
        }
        val path = call.argument<String>("path")
        if (path.isNullOrBlank()) {
            result.error("no_path", "No APK path was given.", null)
            return
        }
        try {
            val file = File(path)
            if (!file.exists()) {
                result.error("missing_apk", "The downloaded APK is gone.", null)
                return
            }
            val uri: Uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                // Read grant: without it the installer cannot open the file.
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    // Needed so the system offers the "install" screen even when
                    // the user has not allowed installs for this app yet.
                    addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
                }
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("install_failed", e.message ?: "The installer refused.", null)
        }
    }
}
