package com.vaktet.vaktet

import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferFastestRefresh()
    }

    override fun onResume() {
        super.onResume()
        preferFastestRefresh()
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
