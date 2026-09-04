package app.mikosea.phone_adas

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sin

/**
 * Native vision core — Phase 0: mock emitter at 10 Hz.
 *
 * The real pipeline (CameraX -> ROI crop -> LiteRT, and later a UVC
 * external-camera frame source) lands here; the Flutter-facing contract
 * below stays identical to iOS.
 *
 * Contract:
 *  - EventChannel `app.mikosea.test/detections`: frames at ~10 Hz.
 *  - MethodChannel `app.mikosea.test/control`: `start` / `stop`.
 */
object AdasCore {
    private const val EVENTS_CHANNEL = "app.mikosea.test/detections"
    private const val CONTROL_CHANNEL = "app.mikosea.test/control"
    private const val TICK_MS = 100L

    private val handler = Handler(Looper.getMainLooper())
    private val toneGenerator by lazy {
        ToneGenerator(AudioManager.STREAM_NOTIFICATION, 85)
    }
    private var sink: EventChannel.EventSink? = null
    private var running = false
    private var phase = 0.0

    private val tick = object : Runnable {
        override fun run() {
            if (!running) return
            emitMockFrame()
            handler.postDelayed(this, TICK_MS)
        }
    }

    fun register(engine: FlutterEngine) {
        EventChannel(engine.dartExecutor.binaryMessenger, EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                    sink = events
                    start()
                }

                override fun onCancel(args: Any?) {
                    stop()
                    sink = null
                }
            })
        MethodChannel(engine.dartExecutor.binaryMessenger, CONTROL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> { start(); result.success(mapOf("textureId" to null)) }
                    "stop" -> { stop(); result.success(null) }
                    "startRecording" -> result.success(false) // phase 3
                    "stopRecording" -> result.success(null)
                    "beep" -> {
                        toneGenerator.startTone(ToneGenerator.TONE_PROP_BEEP2, 200)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun start() {
        if (running) return
        running = true
        handler.postDelayed(tick, TICK_MS)
    }

    private fun stop() {
        running = false
        handler.removeCallbacks(tick)
    }

    private fun emitMockFrame() {
        val events = sink ?: return
        phase += 0.1
        // Three mock vehicles matching the product mockup:
        // motorcycle left ~6 m, car center drifting 30-70 m, car right ~25 m.
        val dMoto = 6.2 + 0.4 * sin(phase / 1.7)
        val dCenter = 50.0 + 20.0 * sin(phase / 3.0)
        val dRight = 25.4 + 1.5 * sin(phase / 2.3)
        fun box(cls: String, cx: Double, groundY: Double, w: Double, hRatio: Double, conf: Double): Map<String, Any> {
            val h = w * hRatio
            return mapOf("cls" to cls, "conf" to conf, "x" to cx - w / 2.0, "y" to groundY - h, "w" to w, "h" to h)
        }
        events.success(
            mapOf(
                "ts" to System.currentTimeMillis(),
                "mock" to true,
                "frameW" to 1920,
                "frameH" to 1080,
                "fx" to 1500.0,
                "detections" to listOf(
                    box("motorcycle", 620.0, 760.0, 0.8 * 1500.0 / dMoto, 1.6, 0.88),
                    box("car", 960.0, 620.0, 1.8 * 1500.0 / dCenter, 0.8, 0.93),
                    box("car", 1330.0, 660.0, 1.8 * 1500.0 / dRight, 0.8, 0.91),
                ),
                "laneCalib" to mapOf("cx" to 960.0, "vy" to 486.0, "n" to 99),
                "lane" to mapOf(
                    "left" to listOf(760.0 - 80.0 * sin(phase / 7.0), 1080.0, 880.0, 626.0),
                    "right" to listOf(1160.0 - 80.0 * sin(phase / 7.0), 1080.0, 1040.0, 626.0),
                    "offset" to 0.65 * sin(phase / 7.0),
                    "conf" to 0.9,
                ),
            ),
        )
    }
}
