package app.mikosea.phone_adas

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
                    "start" -> { start(); result.success(null) }
                    "stop" -> { stop(); result.success(null) }
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
        // A "car" drifting between roughly 30 m and 70 m.
        val w = 65.0 + 25.0 * sin(phase / 3.0)
        events.success(
            mapOf(
                "ts" to System.currentTimeMillis(),
                "mock" to true,
                "frameW" to 1920,
                "frameH" to 1080,
                "detections" to listOf(
                    mapOf(
                        "cls" to "car",
                        "conf" to 0.92,
                        "x" to 960.0 - w / 2.0,
                        "y" to 520.0,
                        "w" to w,
                        "h" to w * 0.8,
                    ),
                ),
            ),
        )
    }
}
