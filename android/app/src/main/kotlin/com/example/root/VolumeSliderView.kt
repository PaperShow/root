package com.example.root

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.drawable.Drawable
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.animation.DecelerateInterpolator
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * A tall, narrow, iOS-style volume slider: a rounded track that fills from the
 * bottom, with a speaker icon that changes with the level.
 *
 * Drag up/down anywhere on it to change the level relative to where it was;
 * a tap jumps straight to the tapped position.
 */
class VolumeSliderView(context: Context) : View(context) {

    /** Called with the new stream level whenever the user changes it. */
    var onLevelChanged: ((Int) -> Unit)? = null

    /** Called on every touch, so the host can postpone auto-collapse. */
    var onInteraction: (() -> Unit)? = null

    private var maxLevel = 15
    private var level = 0
    private var fraction = 0f          // what is drawn (0..1)
    private var animator: ValueAnimator? = null

    private val density = resources.displayMetrics.density
    private val cornerRadius = 20f * density
    private val iconSize = (24 * density).roundToInt()
    private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop

    // slightly lighter than typical dark app backgrounds so the empty track stays visible
    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#E63A3A3D") }
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#F5F5F2") }
    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = density
        color = Color.parseColor("#33FFFFFF")
    }
    private val clip = Path()
    private val rect = RectF()

    private val iconHigh: Drawable? = context.getDrawable(R.drawable.ic_volume_high)?.mutate()
    private val iconLow: Drawable? = context.getDrawable(R.drawable.ic_volume_low)?.mutate()
    private val iconMute: Drawable? = context.getDrawable(R.drawable.ic_volume_mute)?.mutate()

    // touch state
    private var downY = 0f
    private var downFraction = 0f
    private var moved = false

    init {
        isHapticFeedbackEnabled = true
    }

    /** Update from the system (e.g. hardware buttons). Ignored mid-drag. */
    fun setLevel(newLevel: Int, newMax: Int, animate: Boolean) {
        if (isPressed) return
        maxLevel = newMax.coerceAtLeast(1)
        level = newLevel.coerceIn(0, maxLevel)
        val target = level.toFloat() / maxLevel
        if (animate) animateTo(target) else {
            animator?.cancel()
            fraction = target
            invalidate()
        }
    }

    private fun animateTo(target: Float) {
        animator?.cancel()
        animator = ValueAnimator.ofFloat(fraction, target).apply {
            duration = 180
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                fraction = it.animatedValue as Float
                invalidate()
            }
            start()
        }
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        rect.set(0f, 0f, w.toFloat(), h.toFloat())
        clip.reset()
        clip.addRoundRect(rect, cornerRadius, cornerRadius, Path.Direction.CW)
    }

    override fun onDraw(canvas: Canvas) {
        val w = width.toFloat()
        val h = height.toFloat()
        val fillTop = h * (1f - fraction)

        canvas.save()
        canvas.clipPath(clip)
        canvas.drawRect(0f, 0f, w, h, trackPaint)
        canvas.drawRect(0f, fillTop, w, h, fillPaint)
        canvas.restore()
        canvas.drawRoundRect(
            rect.left + density / 2, rect.top + density / 2,
            rect.right - density / 2, rect.bottom - density / 2,
            cornerRadius, cornerRadius, borderPaint
        )

        val icon = when {
            level == 0 -> iconMute
            fraction < 0.5f -> iconLow
            else -> iconHigh
        } ?: return
        val left = ((w - iconSize) / 2).roundToInt()
        val bottomPad = (14 * density).roundToInt()
        val top = (h - bottomPad - iconSize).roundToInt()
        icon.setBounds(left, top, left + iconSize, top + iconSize)
        // dark icon when the white fill covers it, light otherwise
        val covered = fillTop < top + iconSize / 2f
        icon.setTint(if (covered) Color.parseColor("#1C1C1E") else Color.parseColor("#E6FFFFFF"))
        icon.draw(canvas)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        onInteraction?.invoke()
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                animator?.cancel()
                isPressed = true
                downY = event.y
                downFraction = fraction
                moved = false
                parent?.requestDisallowInterceptTouchEvent(true)
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                if (!moved && abs(event.y - downY) > touchSlop) moved = true
                if (moved) {
                    fraction = (downFraction + (downY - event.y) / height).coerceIn(0f, 1f)
                    applyFraction()
                    invalidate()
                }
                return true
            }
            MotionEvent.ACTION_UP -> {
                if (!moved) {
                    fraction = (1f - event.y / height).coerceIn(0f, 1f)
                    applyFraction()
                }
                isPressed = false
                animateTo(level.toFloat() / maxLevel)   // settle on the real step
                return true
            }
            MotionEvent.ACTION_CANCEL -> {
                isPressed = false
                animateTo(level.toFloat() / maxLevel)
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    private fun applyFraction() {
        val newLevel = (fraction * maxLevel).roundToInt().coerceIn(0, maxLevel)
        if (newLevel != level) {
            level = newLevel
            performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
            onLevelChanged?.invoke(newLevel)
        }
    }
}
