package com.vaktet.vaktet

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val NOTIF_CHANNEL = "com.vaktet.vaktet/notifications"
        private const val REQ_POST_NOTIFICATIONS = 4001
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferFastestRefresh()
        PrayerNotifications.ensureChannel(this)
    }

    override fun onResume() {
        super.onResume()
        preferFastestRefresh()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> {
                        result.success(hasNotificationPermission())
                    }
                    "requestPermission" -> {
                        if (hasNotificationPermission()) {
                            result.success(true)
                        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            pendingPermissionResult?.success(false)
                            pendingPermissionResult = result
                            requestPermissions(
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                REQ_POST_NOTIFICATIONS
                            )
                        } else {
                            result.success(true)
                        }
                    }
                    "schedule" -> {
                        @Suppress("UNCHECKED_CAST")
                        val items = call.argument<List<Map<String, Any>>>("items") ?: emptyList()
                        PrayerNotifications.scheduleAll(this, items)
                        result.success(true)
                    }
                    "cancelAll" -> {
                        PrayerNotifications.cancelAll(this)
                        result.success(true)
                    }
                    "showTest" -> {
                        val title = call.argument<String>("title") ?: "Vaktet"
                        val body = call.argument<String>("body") ?: "Njoftimet e vakteve janë aktive."
                        PrayerNotifications.showNotification(this, 99999, title, body)
                        result.success(true)
                    }
                    "updateWidget" -> {
                        @Suppress("UNCHECKED_CAST")
                        val items = call.argument<List<Map<String, Any>>>("items") ?: emptyList()
                        VaktetWidgetProvider.saveScheduleAndRefresh(this, items)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == REQ_POST_NOTIFICATIONS) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    /**
     * Asks for the screen's fastest refresh rate (90, 120 Hz …) at its current resolution. Without it, many
     * phones keep an app like this one at 60 Hz, and the sky and the swipes move in half the steps the screen
     * could show. A phone its owner has set to a fixed 60 Hz offers only that, so nothing changes there.
     */
    private fun preferFastestRefresh() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val screen = currentScreen() ?: return
        val current = screen.mode
        val fastest =
            screen.supportedModes
                .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
                .maxByOrNull { it.refreshRate } ?: return
        val params = window.attributes
        if (params.preferredDisplayModeId == fastest.modeId) return
        params.preferredDisplayModeId = fastest.modeId
        window.attributes = params
    }

    @Suppress("DEPRECATION")
    private fun currentScreen(): Display? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay
}
