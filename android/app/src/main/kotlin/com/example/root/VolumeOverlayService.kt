package com.example.root

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView

class VolumeOverlayService : Service() {

    companion object {
        var isRunning: Boolean = false
    }

    private var windowManager: WindowManager? = null
    private var audioManager: AudioManager? = null

    private var floatingView: FrameLayout? = null
    private var collapsedPill: LinearLayout? = null
    private var expandedPanel: LinearLayout? = null

    private var volumeTextPill: TextView? = null
    private var volumeIconPill: TextView? = null

    private var sliderValueText: TextView? = null
    private var volumeSeekBar: SeekBar? = null
    private var currentStreamNameText: TextView? = null

    private var currentStreamType = AudioManager.STREAM_MUSIC
    private var isExpanded = false

    private lateinit var layoutParams: WindowManager.LayoutParams
    private val mainHandler = Handler(Looper.getMainLooper())

    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var isDragging = false
    private var isReceiverRegistered = false

    private val volumeChangeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            try {
                updateVolumeUI()
            } catch (_: Exception) {}
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                stopSelf()
                return
            }

            windowManager = getSystemService(WINDOW_SERVICE) as? WindowManager
            audioManager = getSystemService(AUDIO_SERVICE) as? AudioManager

            if (windowManager == null || audioManager == null) {
                stopSelf()
                return
            }

            createFloatingOverlay()

            val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
            registerReceiver(volumeChangeReceiver, filter)
            isReceiverRegistered = true
            isRunning = true
        } catch (e: Throwable) {
            e.printStackTrace()
            isRunning = false
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        if (isReceiverRegistered) {
            try {
                unregisterReceiver(volumeChangeReceiver)
            } catch (_: Exception) {}
            isReceiverRegistered = false
        }

        floatingView?.let { view ->
            try {
                windowManager?.removeView(view)
            } catch (_: Exception) {}
        }
        floatingView = null
    }

    private fun createFloatingOverlay() {
        val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            windowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 40
            y = 260
        }

        floatingView = FrameLayout(this).apply {
            clipChildren = false
            clipToPadding = false
        }

        collapsedPill = buildCollapsedPill()
        expandedPanel = buildExpandedPanel()

        expandedPanel?.visibility = View.GONE

        floatingView?.addView(collapsedPill)
        floatingView?.addView(expandedPanel)

        setupTouchHandling(collapsedPill!!)

        try {
            windowManager?.addView(floatingView, layoutParams)
            updateVolumeUI()
        } catch (e: Throwable) {
            e.printStackTrace()
            stopSelf()
        }
    }

    private fun buildCollapsedPill(): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(10), dp(10), dp(10), dp(10))

            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#EE0A0A0A"))
                cornerRadius = dp(24).toFloat()
                setStroke(dp(1), Color.parseColor("#5569FF94"))
            }
            background = bg
            elevation = dp(8).toFloat()

            volumeIconPill = TextView(context).apply {
                text = "🔊"
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                gravity = Gravity.CENTER
            }

            addView(volumeIconPill)
        }
    }

    private fun buildExpandedPanel(): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))

            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#F50D0D0D"))
                cornerRadius = dp(18).toFloat()
                setStroke(dp(1), Color.parseColor("#5569FF94"))
            }
            background = bg
            elevation = dp(12).toFloat()

            // Header row - minimal with close button
            val headerRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            }

            val spacer = View(context).apply {
                layoutParams = LinearLayout.LayoutParams(0, 0, 1.0f)
            }

            val closeButton = TextView(context).apply {
                text = "✕"
                setTextColor(Color.parseColor("#888888"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                setPadding(dp(8), dp(4), dp(8), dp(4))
                setOnClickListener { collapseToPill() }
            }

            headerRow.addView(spacer)
            headerRow.addView(closeButton)
            addView(headerRow)

            // Stream buttons row
            val streamsRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                setPadding(0, dp(12), 0, dp(10))
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            }

            fun createStreamBtn(label: String, stream: Int): TextView {
                return TextView(context).apply {
                    text = label
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
                    typeface = Typeface.MONOSPACE
                    setPadding(dp(8), dp(6), dp(8), dp(6))
                    val btnBg = GradientDrawable().apply {
                        cornerRadius = dp(8).toFloat()
                        setColor(if (currentStreamType == stream) Color.parseColor("#3369FF94") else Color.parseColor("#1F1F1F"))
                        setStroke(dp(1), if (currentStreamType == stream) Color.parseColor("#69FF94") else Color.parseColor("#333333"))
                    }
                    background = btnBg
                    setTextColor(if (currentStreamType == stream) Color.parseColor("#69FF94") else Color.parseColor("#AAAAAA"))
                    val params = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f).apply {
                        setMargins(dp(2), 0, dp(2), 0)
                    }
                    layoutParams = params
                    gravity = Gravity.CENTER
                    setOnClickListener {
                        currentStreamType = stream
                        rebuildStreamButtons(streamsRow)
                        updateVolumeUI()
                    }
                }
            }

            streamsRow.addView(createStreamBtn("MEDIA", AudioManager.STREAM_MUSIC))
            streamsRow.addView(createStreamBtn("RING", AudioManager.STREAM_RING))
            streamsRow.addView(createStreamBtn("NOTIF", AudioManager.STREAM_NOTIFICATION))
            streamsRow.addView(createStreamBtn("ALARM", AudioManager.STREAM_ALARM))
            addView(streamsRow)

            // Stream name & percentage readout
            val readoutRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(4), dp(4), dp(4), dp(6))
            }

            currentStreamNameText = TextView(context).apply {
                text = "MEDIA STREAM"
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                typeface = Typeface.MONOSPACE
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
            }

            sliderValueText = TextView(context).apply {
                text = "60%"
                setTextColor(Color.parseColor("#69FF94"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                typeface = Typeface.MONOSPACE
            }

            readoutRow.addView(currentStreamNameText)
            readoutRow.addView(sliderValueText)
            addView(readoutRow)

            // Interactive SeekBar Slider
            volumeSeekBar = SeekBar(context).apply {
                val am = audioManager
                val max = am?.getStreamMaxVolume(currentStreamType) ?: 15
                this.max = max
                progress = am?.getStreamVolume(currentStreamType) ?: 0
                layoutParams = LinearLayout.LayoutParams(dp(220), LinearLayout.LayoutParams.WRAP_CONTENT)
                setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                    override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                        if (fromUser) {
                            try {
                                audioManager?.setStreamVolume(currentStreamType, progress, 0)
                                updateVolumeUI()
                            } catch (_: Exception) {}
                        }
                    }
                    override fun onStartTrackingTouch(seekBar: SeekBar?) {}
                    override fun onStopTrackingTouch(seekBar: SeekBar?) {}
                })
            }
            addView(volumeSeekBar)

            // Bottom quick actions row (Mute, -, +, Max)
            val actionsRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                setPadding(0, dp(8), 0, 0)
            }

            fun createActionBtn(label: String, onClick: () -> Unit): TextView {
                return TextView(context).apply {
                    text = label
                    setTextColor(Color.WHITE)
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
                    typeface = Typeface.MONOSPACE
                    setPadding(dp(10), dp(5), dp(10), dp(5))
                    val btnBg = GradientDrawable().apply {
                        cornerRadius = dp(6).toFloat()
                        setColor(Color.parseColor("#222222"))
                    }
                    background = btnBg
                    val params = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f).apply {
                        setMargins(dp(3), 0, dp(3), 0)
                    }
                    layoutParams = params
                    gravity = Gravity.CENTER
                    setOnClickListener { onClick() }
                }
            }

            actionsRow.addView(createActionBtn("🔇") {
                try {
                    audioManager?.setStreamVolume(currentStreamType, 0, 0)
                    updateVolumeUI()
                } catch (_: Exception) {}
            })

            actionsRow.addView(createActionBtn("-") {
                try {
                    val current = audioManager?.getStreamVolume(currentStreamType) ?: 0
                    if (current > 0) {
                        audioManager?.setStreamVolume(currentStreamType, current - 1, 0)
                        updateVolumeUI()
                    }
                } catch (_: Exception) {}
            })

            actionsRow.addView(createActionBtn("+") {
                try {
                    val current = audioManager?.getStreamVolume(currentStreamType) ?: 0
                    val max = audioManager?.getStreamMaxVolume(currentStreamType) ?: 15
                    if (current < max) {
                        audioManager?.setStreamVolume(currentStreamType, current + 1, 0)
                        updateVolumeUI()
                    }
                } catch (_: Exception) {}
            })

            actionsRow.addView(createActionBtn("MAX") {
                try {
                    val max = audioManager?.getStreamMaxVolume(currentStreamType) ?: 15
                    audioManager?.setStreamVolume(currentStreamType, max, 0)
                    updateVolumeUI()
                } catch (_: Exception) {}
            })

            addView(actionsRow)
        }
    }

    private fun rebuildStreamButtons(container: LinearLayout) {
        val count = container.childCount
        val streams = listOf(
            AudioManager.STREAM_MUSIC,
            AudioManager.STREAM_RING,
            AudioManager.STREAM_NOTIFICATION,
            AudioManager.STREAM_ALARM
        )
        for (i in 0 until count) {
            val child = container.getChildAt(i) as? TextView ?: continue
            val stream = streams.getOrNull(i) ?: continue
            val isSelected = stream == currentStreamType
            val bg = GradientDrawable().apply {
                cornerRadius = dp(8).toFloat()
                setColor(if (isSelected) Color.parseColor("#3369FF94") else Color.parseColor("#1F1F1F"))
                setStroke(dp(1), if (isSelected) Color.parseColor("#69FF94") else Color.parseColor("#333333"))
            }
            child.background = bg
            child.setTextColor(if (isSelected) Color.parseColor("#69FF94") else Color.parseColor("#AAAAAA"))
        }
    }

    private fun setupTouchHandling(view: View) {
        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = layoutParams.x
                    initialY = layoutParams.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                        isDragging = true
                        layoutParams.x = initialX + dx
                        layoutParams.y = initialY + dy
                        try {
                            windowManager?.updateViewLayout(floatingView, layoutParams)
                        } catch (_: Exception) {}
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        expandToPanel()
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun expandToPanel() {
        if (isExpanded) return
        isExpanded = true
        collapsedPill?.visibility = View.GONE
        expandedPanel?.visibility = View.VISIBLE
        updateVolumeUI()

        mainHandler.removeCallbacks(autoCollapseRunnable)
        mainHandler.postDelayed(autoCollapseRunnable, 8000)
    }

    private val autoCollapseRunnable = Runnable {
        collapseToPill()
    }

    private fun collapseToPill() {
        if (!isExpanded) return
        isExpanded = false
        mainHandler.removeCallbacks(autoCollapseRunnable)
        expandedPanel?.visibility = View.GONE
        collapsedPill?.visibility = View.VISIBLE
        updateVolumeUI()
    }

    private fun updateVolumeUI() {
        val am = audioManager ?: return
        val currentVol = am.getStreamVolume(currentStreamType)
        val maxVol = am.getStreamMaxVolume(currentStreamType)
        val percent = if (maxVol > 0) ((currentVol.toFloat() / maxVol) * 100).toInt() else 0

        val icon = when {
            percent == 0 -> "🔇"
            percent < 40 -> "🔉"
            else -> "🔊"
        }

        volumeIconPill?.text = icon

        volumeSeekBar?.max = maxVol
        volumeSeekBar?.progress = currentVol
        sliderValueText?.text = "$percent%"

        val streamName = when (currentStreamType) {
            AudioManager.STREAM_MUSIC -> "MEDIA"
            AudioManager.STREAM_RING -> "RINGTONE"
            AudioManager.STREAM_NOTIFICATION -> "NOTIF"
            AudioManager.STREAM_ALARM -> "ALARM"
            else -> "VOLUME"
        }
        currentStreamNameText?.text = streamName
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }
}
