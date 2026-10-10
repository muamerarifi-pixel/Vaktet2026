package com.vaktet.vaktet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    /**
     * Tells the app whether the phone's battery saver is on (now, and whenever it changes), so the sky can stay
     * still while it is.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "vaktet/power_save").setStreamHandler(
            object : EventChannel.StreamHandler {
                private var receiver: BroadcastReceiver? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    val power = getSystemService(Context.POWER_SERVICE) as PowerManager
                    events.success(power.isPowerSaveMode)
                    val changes = object : BroadcastReceiver() {
                        override fun onReceive(context: Context, intent: Intent) {
                            events.success(power.isPowerSaveMode)
                        }
                    }
                    val filter = IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
                    // a broadcast from the system only: nothing else needs to reach this receiver
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(changes, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(changes, filter)
                    }
                    receiver = changes
                }

                override fun onCancel(arguments: Any?) {
                    receiver?.let { unregisterReceiver(it) }
                    receiver = null
                }
            },
        )
    }
}
