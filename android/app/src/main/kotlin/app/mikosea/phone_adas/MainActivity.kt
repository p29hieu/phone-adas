package app.mikosea.phone_adas

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val info = packageManager.getPackageInfo(packageName, 0)
        @Suppress("DEPRECATION")
        val code = if (android.os.Build.VERSION.SDK_INT >= 28) {
            info.longVersionCode.toString()
        } else {
            info.versionCode.toString()
        }
        AdasCore.setVersion(info.versionName ?: "?", code)
        AdasCore.register(flutterEngine)
    }
}
