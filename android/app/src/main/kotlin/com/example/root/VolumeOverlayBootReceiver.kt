package com.example.root

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Brings the floating volume widget back after a reboot, an app update, or a
 * periodic watchdog check, if the user left it on.
 */
class VolumeOverlayBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            VolumeOverlayService.ACTION_WATCHDOG -> VolumeOverlayService.restoreIfEnabled(context)
        }
    }
}
