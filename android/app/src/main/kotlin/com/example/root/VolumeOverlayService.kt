package com.example.root

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

/**
 * Floating volume widget drawn over other apps.
 *
 * Runs as a foreground service so Android keeps it alive after the app leaves
 * the screen, is swiped away from recents, or is reclaimed for memory. Whether
 * the user wants it on is remembered, so it also comes back after a reboot or
 * app update (see [VolumeOverlayBootReceiver]) and whenever the app is opened.
 */
class VolumeOverlayService : Service() {

    companion object {
        @Volatile
        var isRunning: Boolean = false

        private const val PREFS = "volume_widget"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_X = "x"
        private const val KEY_Y = "y"
        private const val CHANNEL_ID = "volume_widget"
        private const val NOTIFICATION_ID = 4107
        const val ACTION_STOP = "com.example.root.action.STOP_VOLUME_WIDGET"

        private const val AUTO_COLLAPSE_MS = 4000L

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        fun isEnabled(context: Context) = prefs(context).getBoolean(KEY_ENABLED, false)

        /** Turn the widget on and remember that choice. */
        fun start(context: Context): Boolean {
            if (!Settings.canDrawOverlays(context)) return false
            prefs(context).edit().putBoolean(KEY_ENABLED, true).apply()
            val intent = Intent(context, VolumeOverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            return true
        }

        /** Turn the widget off and remember that choice. */
        fun stop(context: Context) {
            prefs(context).edit().putBoolean(KEY_ENABLED, false).apply()
            context.stopService(Intent(context, VolumeOverlayService::class.java))
        }

        /** Bring the widget back if the user left it on but it isn't running. */
        fun restoreIfEnabled(context: Context) {
            if (!isRunning && isEnabled(context)) {
                try {
                    start(context)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    private data class StreamOption(val type: Int, val label: String)

    private val streams = listOf(
        StreamOption(AudioManager.STREAM_MUSIC, "media"),
        StreamOption(AudioManager.STREAM_RING, "ring"),
        StreamOption(AudioManager.STREAM_NOTIFICATION, "alerts"),
        StreamOption(AudioManager.STREAM_ALARM, "alarm"),
    )
    private var streamIndex = 0
    private val currentStream get() = streams[streamIndex].type

    private var windowManager: WindowManager? = null
    private var audioManager: AudioManager? = null

    private var rootView: FrameLayout? = null
    private var pill: FrameLayout? = null
    private var pillIcon: ImageView? = null
    private var panel: LinearLayout? = null
    private var slider: VolumeSliderView? = null
    private var percentText: TextView? = null
    private var streamChip: TextView? = null

    private lateinit var params: WindowManager.LayoutParams
    private val handler = Handler(Looper.getMainLooper())
    private var isExpanded = false
    private var receiverRegistered = false

    // where the collapsed pill sits; restored when the panel collapses
    private var pillX = 0
    private var pillY = 0

    private val volumeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            refresh(animate = true)
        }
    }

    private val autoCollapse = Runnable { collapse() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        // Must happen first: a service started with startForegroundService()
        // that stops without calling startForeground() crashes the app.
        goForeground()

        if (!Settings.canDrawOverlays(this)) {
            prefs(this).edit().putBoolean(KEY_ENABLED, false).apply()
            stopSelf()
            return
        }
        windowManager = getSystemService(WINDOW_SERVICE) as? WindowManager
        audioManager = getSystemService(AUDIO_SERVICE) as? AudioManager
        if (windowManager == null || audioManager == null) {
            stopSelf()
            return
        }

        try {
            createOverlay()
            val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(volumeReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(volumeReceiver, filter)
            }
            receiverRegistered = true
            isRunning = true
        } catch (e: Throwable) {
            e.printStackTrace()
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stop(this)
            return START_NOT_STICKY
        }
        // Restarted by the system after being killed: re-assert foreground.
        goForeground()
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        handler.removeCallbacksAndMessages(null)
        if (receiverRegistered) {
            try { unregisterReceiver(volumeReceiver) } catch (_: Exception) {}
            receiverRegistered = false
        }
        rootView?.let { try { windowManager?.removeView(it) } catch (_: Exception) {} }
        rootView = null
        super.onDestroy()
    }

    // ── Foreground notification ─────────────────────────────────────────

    private fun goForeground() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            nm.getNotificationChannel(CHANNEL_ID) == null
        ) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Volume widget", NotificationManager.IMPORTANCE_MIN).apply {
                    description = "Keeps the floating volume widget on screen"
                    setShowBadge(false)
                }
            )
        }

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val openApp = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            flags
        )
        val stopIntent = PendingIntent.getService(
            this, 1,
            Intent(this, VolumeOverlayService::class.java).setAction(ACTION_STOP),
            flags
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_MIN)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_root)
            .setContentTitle("Volume widget is on")
            .setContentText("Tap the floating button to change volume")
            .setContentIntent(openApp)
            .setOngoing(true)
            .setShowWhen(false)
            .addAction(Notification.Action.Builder(null, "Turn off", stopIntent).build())
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    // ── Overlay UI ──────────────────────────────────────────────────────

    private fun createOverlay() {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        val p = prefs(this)
        val (screenW, screenH) = screenSize()
        pillX = p.getInt(KEY_X, screenW - dp(PILL_W) - dp(EDGE_MARGIN))
        pillY = p.getInt(KEY_Y, (screenH * 0.35).toInt())
        params.x = pillX
        params.y = pillY

        rootView = object : FrameLayout(this) {
            @SuppressLint("ClickableViewAccessibility")
            override fun onTouchEvent(event: MotionEvent): Boolean {
                if (event.action == MotionEvent.ACTION_OUTSIDE) {
                    collapse()
                    return true
                }
                return super.onTouchEvent(event)
            }
        }.apply {
            clipChildren = false
            clipToPadding = false
        }

        pill = buildPill()
        panel = buildPanel().apply { visibility = View.GONE }
        rootView!!.addView(pill)
        rootView!!.addView(panel)

        windowManager!!.addView(rootView, params)
        refresh(animate = false)
    }

    private fun buildPill(): FrameLayout {
        val icon = ImageView(this).apply {
            setImageResource(R.drawable.ic_volume_high)
            setColorFilter(Color.parseColor("#E6FFFFFF"))
        }
        pillIcon = icon
        return FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(dp(PILL_W), dp(PILL_H))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E63A3A3D"))
                cornerRadius = dp(PILL_W / 2).toFloat()
                setStroke(dp(1), Color.parseColor("#33FFFFFF"))
            }
            elevation = dp(6).toFloat()
            addView(icon, FrameLayout.LayoutParams(dp(18), dp(18), Gravity.CENTER))
            setOnTouchListener(PillDragListener())
        }
    }

    private fun buildPanel(): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(6), dp(6), dp(6), dp(6))

            percentText = TextView(context).apply {
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                gravity = Gravity.CENTER
                setShadowLayer(dp(4).toFloat(), 0f, 0f, Color.parseColor("#99000000"))
                setPadding(0, 0, 0, dp(8))
            }
            addView(percentText)

            slider = VolumeSliderView(context).apply {
                elevation = dp(8).toFloat()
                onInteraction = { scheduleCollapse() }
                onLevelChanged = { level ->
                    try { audioManager?.setStreamVolume(currentStream, level, 0) } catch (_: Exception) {}
                    updateLabels()
                }
            }
            addView(slider, LinearLayout.LayoutParams(dp(SLIDER_W), dp(SLIDER_H)))

            streamChip = TextView(context).apply {
                setTextColor(Color.parseColor("#E6FFFFFF"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
                gravity = Gravity.CENTER
                setPadding(dp(10), dp(5), dp(10), dp(5))
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#E63A3A3D"))
                    cornerRadius = dp(12).toFloat()
                    setStroke(dp(1), Color.parseColor("#33FFFFFF"))
                }
                setOnClickListener {
                    streamIndex = (streamIndex + 1) % streams.size
                    refresh(animate = true)
                    scheduleCollapse()
                }
            }
            addView(streamChip, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(10) })
        }
    }

    private fun refresh(animate: Boolean) {
        val am = audioManager ?: return
        val cur = am.getStreamVolume(currentStream)
        val max = am.getStreamMaxVolume(currentStream)
        slider?.setLevel(cur, max, animate)
        updateLabels()
    }

    private fun updateLabels() {
        val am = audioManager ?: return
        val cur = am.getStreamVolume(currentStream)
        val max = am.getStreamMaxVolume(currentStream).coerceAtLeast(1)
        val pct = cur * 100 / max
        percentText?.text = "$pct%"
        streamChip?.text = streams[streamIndex].label
        pillIcon?.setImageResource(
            when {
                cur == 0 -> R.drawable.ic_volume_mute
                pct < 50 -> R.drawable.ic_volume_low
                else -> R.drawable.ic_volume_high
            }
        )
    }

    // ── Expand / collapse ───────────────────────────────────────────────

    private fun expand() {
        if (isExpanded) return
        isExpanded = true
        refresh(animate = false)
        pill?.visibility = View.GONE
        panel?.visibility = View.VISIBLE

        // open from whichever screen edge the pill is docked to
        panel!!.measure(View.MeasureSpec.UNSPECIFIED, View.MeasureSpec.UNSPECIFIED)
        val pw = panel!!.measuredWidth
        val ph = panel!!.measuredHeight
        val (screenW, screenH) = screenSize()
        val onRight = pillX + dp(PILL_W) / 2 > screenW / 2
        params.x = if (onRight) screenW - pw - dp(EDGE_MARGIN) else dp(EDGE_MARGIN)
        params.y = (pillY + dp(PILL_H) / 2 - ph / 2).coerceIn(dp(24), (screenH - ph - dp(24)).coerceAtLeast(0))
        applyLayout()
        panel!!.alpha = 0f
        panel!!.scaleX = 0.9f
        panel!!.scaleY = 0.9f
        panel!!.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(160).start()
        scheduleCollapse()
    }

    private fun collapse() {
        if (!isExpanded) return
        isExpanded = false
        handler.removeCallbacks(autoCollapse)
        panel?.visibility = View.GONE
        pill?.visibility = View.VISIBLE
        params.x = pillX
        params.y = pillY
        applyLayout()
    }

    private fun scheduleCollapse() {
        handler.removeCallbacks(autoCollapse)
        handler.postDelayed(autoCollapse, AUTO_COLLAPSE_MS)
    }

    private fun applyLayout() {
        try { windowManager?.updateViewLayout(rootView, params) } catch (_: Exception) {}
    }

    /** Drag the pill around; on release it snaps to the nearest side. A tap expands it. */
    private inner class PillDragListener : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var touchX = 0f
        private var touchY = 0f
        private var dragging = false
        private val slop = ViewConfiguration.get(this@VolumeOverlayService).scaledTouchSlop

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouch(v: View, e: MotionEvent): Boolean {
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x; startY = params.y
                    touchX = e.rawX; touchY = e.rawY
                    dragging = false
                    v.animate().scaleX(0.92f).scaleY(0.92f).setDuration(80).start()
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - touchX
                    val dy = e.rawY - touchY
                    if (!dragging && (abs(dx) > slop || abs(dy) > slop)) dragging = true
                    if (dragging) {
                        params.x = startX + dx.toInt()
                        params.y = startY + dy.toInt()
                        applyLayout()
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    v.animate().scaleX(1f).scaleY(1f).setDuration(120).start()
                    if (dragging) snapToEdge() else if (e.actionMasked == MotionEvent.ACTION_UP) expand()
                }
            }
            return true
        }
    }

    private fun snapToEdge() {
        val (screenW, screenH) = screenSize()
        val w = dp(PILL_W)
        val h = dp(PILL_H)
        pillX = if (params.x + w / 2 > screenW / 2) screenW - w - dp(EDGE_MARGIN) else dp(EDGE_MARGIN)
        pillY = params.y.coerceIn(dp(24), (screenH - h - dp(24)).coerceAtLeast(0))
        params.x = pillX
        params.y = pillY
        applyLayout()
        prefs(this).edit().putInt(KEY_X, pillX).putInt(KEY_Y, pillY).apply()
    }

    private fun screenSize(): Pair<Int, Int> {
        val wm = windowManager ?: return Pair(
            resources.displayMetrics.widthPixels, resources.displayMetrics.heightPixels
        )
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val b = wm.currentWindowMetrics.bounds
            Pair(b.width(), b.height())
        } else {
            Pair(resources.displayMetrics.widthPixels, resources.displayMetrics.heightPixels)
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}

// sizes in dp
private const val PILL_W = 36
private const val PILL_H = 56
private const val SLIDER_W = 56
private const val SLIDER_H = 176
private const val EDGE_MARGIN = 6
