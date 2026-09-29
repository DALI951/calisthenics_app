package com.dali951.calisthenics_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The in-app APK installer needs a real Android intent (MIME type +
        // read grant) that url_launcher cannot send. See UpdateInstallerChannel.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UpdateInstallerChannel.CHANNEL,
        ).setMethodCallHandler(UpdateInstallerChannel(applicationContext))
    }
}
