package com.example.root

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.WallpaperManager
import android.app.admin.DevicePolicyManager
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.provider.CalendarContract
import android.provider.Settings
import android.media.AudioManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.root/launcher"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setMinimalRecentApps()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDefaultLauncher" -> {
                    result.success(isDefaultLauncher())
                }
                "openLauncherSettings" -> {
                    openLauncherSettings()
                    result.success(null)
                }
                "setBlackWallpaper" -> {
                    val which = call.argument<Int>("which") ?: 3 // 3 = both
                    val color = call.argument<Int>("color") ?: Color.BLACK
                    val success = setSolidWallpaper(which, color)
                    result.success(success)
                }
                "canSetWallpaper" -> {
                    result.success(WallpaperManager.getInstance(this).isSetWallpaperAllowed)
                }
                "getSystemInfo" -> {
                    val info = getSystemInfo()
                    result.success(info)
                }
                "lockScreen" -> {
                    lockScreen()
                    result.success(null)
                }
                "isOverlayPermissionGranted" -> {
                    val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(granted)
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "startVolumeOverlay" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                            result.success(false)
                        } else {
                            val intent = Intent(this, VolumeOverlayService::class.java)
                            startService(intent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.success(false)
                    }
                }
                "stopVolumeOverlay" -> {
                    try {
                        val intent = Intent(this, VolumeOverlayService::class.java)
                        stopService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.success(false)
                    }
                }
                "isVolumeOverlayRunning" -> {
                    result.success(VolumeOverlayService.isRunning)
                }
                "getVolumeLevels" -> {
                    val am = getSystemService(AUDIO_SERVICE) as AudioManager
                    val map = hashMapOf(
                        "media" to am.getStreamVolume(AudioManager.STREAM_MUSIC),
                        "mediaMax" to am.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
                        "ring" to am.getStreamVolume(AudioManager.STREAM_RING),
                        "ringMax" to am.getStreamMaxVolume(AudioManager.STREAM_RING),
                        "notification" to am.getStreamVolume(AudioManager.STREAM_NOTIFICATION),
                        "notificationMax" to am.getStreamMaxVolume(AudioManager.STREAM_NOTIFICATION),
                        "alarm" to am.getStreamVolume(AudioManager.STREAM_ALARM),
                        "alarmMax" to am.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                        "call" to am.getStreamVolume(AudioManager.STREAM_VOICE_CALL),
                        "callMax" to am.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL)
                    )
                    result.success(map)
                }
                "setVolumeLevel" -> {
                    val am = getSystemService(AUDIO_SERVICE) as AudioManager
                    val streamName = call.argument<String>("stream") ?: "media"
                    val level = call.argument<Int>("level") ?: 0
                    val streamType = when (streamName) {
                        "media" -> AudioManager.STREAM_MUSIC
                        "ring" -> AudioManager.STREAM_RING
                        "notification" -> AudioManager.STREAM_NOTIFICATION
                        "alarm" -> AudioManager.STREAM_ALARM
                        "call" -> AudioManager.STREAM_VOICE_CALL
                        else -> AudioManager.STREAM_MUSIC
                    }
                    am.setStreamVolume(streamType, level, 0)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        setMinimalRecentApps()
    }

    private fun setMinimalRecentApps() {
        val taskDescription = ActivityManager.TaskDescription(
            "minimal",
            0,
            Color.BLACK
        )
        setTaskDescription(taskDescription)
    }

    private fun setSolidWallpaper(which: Int, color: Int): Boolean {
        return try {
            val wm = WallpaperManager.getInstance(this)
            // Create a 1x1 bitmap of the given color — Android tiles/stretches it
            val bitmap = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            canvas.drawColor(color)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // FLAG_SYSTEM = 1 (home), FLAG_LOCK = 2 (lock screen), 3 = both
                wm.setBitmap(bitmap, null, true, which)
            } else {
                wm.setBitmap(bitmap)
            }
            bitmap.recycle()
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun isDefaultLauncher(): Boolean {
        val intent = Intent(Intent.ACTION_MAIN)
        intent.addCategory(Intent.CATEGORY_HOME)
        val resolveInfo: ResolveInfo? = context.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        val currentHomePackage = resolveInfo?.activityInfo?.packageName
        return currentHomePackage == context.packageName
    }

    private fun openLauncherSettings() {
        val intent = Intent(Settings.ACTION_HOME_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    private fun lockScreen() {
        val dpm = getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(this, TurnOffReceiver::class.java)

        if (dpm.isAdminActive(adminComponent)) {
            dpm.lockNow()
        } else {
            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
            intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
            intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Double tap to lock screen requires Device Admin permission.")
            startActivity(intent)
        }
    }

    // ─── SYSTEM INFO (neofetch) ──────────────────────────

    private fun getSystemInfo(): HashMap<String, Any?> {
        val info = HashMap<String, Any?>()

        // ── Network ──
        try {
            val connectivityManager = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = connectivityManager.activeNetwork
            val capabilities = network?.let { connectivityManager.getNetworkCapabilities(it) }

            if (capabilities == null) {
                info["networkType"] = "offline"
                info["wifiSsid"] = null
            } else if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                info["networkType"] = "wifi"
                // Try to get SSID (requires location on Android 8+, may return <unknown ssid>)
                try {
                    @Suppress("DEPRECATION")
                    val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
                    @Suppress("DEPRECATION")
                    val wifiInfo = wifiManager.connectionInfo
                    val ssid = wifiInfo?.ssid?.replace("\"", "") ?: "unknown"
                    info["wifiSsid"] = if (ssid == "<unknown ssid>" || ssid.isEmpty()) null else ssid
                } catch (_: Exception) {
                    info["wifiSsid"] = null
                }
            } else if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
                info["networkType"] = "cellular"
                info["wifiSsid"] = null
            } else {
                info["networkType"] = "other"
                info["wifiSsid"] = null
            }
        } catch (_: Exception) {
            info["networkType"] = "unknown"
            info["wifiSsid"] = null
        }

        // ── Screen time ──
        try {
            // Check if usage stats permission is granted
            val appOps = getSystemService(APP_OPS_SERVICE) as AppOpsManager
            val mode = appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )

            if (mode == AppOpsManager.MODE_ALLOWED) {
                val usageStatsManager = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
                val calendar = Calendar.getInstance()
                calendar.set(Calendar.HOUR_OF_DAY, 0)
                calendar.set(Calendar.MINUTE, 0)
                calendar.set(Calendar.SECOND, 0)
                calendar.set(Calendar.MILLISECOND, 0)

                val stats = usageStatsManager.queryUsageStats(
                    UsageStatsManager.INTERVAL_DAILY,
                    calendar.timeInMillis,
                    System.currentTimeMillis()
                )

                val totalTimeMs = stats?.sumOf { it.totalTimeInForeground } ?: 0L
                info["screenTimeMinutes"] = (totalTimeMs / 1000 / 60).toInt()
            } else {
                info["screenTimeMinutes"] = -1 // Permission not granted
            }
        } catch (_: Exception) {
            info["screenTimeMinutes"] = -1
        }

        // ── Next calendar event ──
        try {
            val now = System.currentTimeMillis()
            val endTime = now + 7L * 24 * 60 * 60 * 1000 // 7 days ahead

            val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
            ContentUris.appendId(builder, now)
            ContentUris.appendId(builder, endTime)

            val projection = arrayOf(
                CalendarContract.Instances.TITLE,
                CalendarContract.Instances.BEGIN
            )
            val sortOrder = "${CalendarContract.Instances.BEGIN} ASC"

            val cursor = contentResolver.query(
                builder.build(),
                projection,
                null,
                null,
                sortOrder
            )

            if (cursor?.moveToFirst() == true) {
                val title = cursor.getString(0) ?: "untitled"
                val begin = cursor.getLong(1)
                val dateFormat = SimpleDateFormat("MMM d, HH:mm", Locale.getDefault())
                info["nextEventTitle"] = title
                info["nextEventTime"] = dateFormat.format(begin)
            } else {
                info["nextEventTitle"] = null
                info["nextEventTime"] = null
            }
            cursor?.close()
        } catch (_: Exception) {
            info["nextEventTitle"] = null
            info["nextEventTime"] = null
        }

        // ── Device info ──
        info["deviceModel"] = Build.MODEL
        info["androidVersion"] = Build.VERSION.RELEASE

        return info
    }
}
