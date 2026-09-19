package com.phaseguard.phaseguard

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.Executors

/**
 * Emits phone call state to Flutter. Number is available on API < 31 when the OS provides it.
 */
object PhoneCallEmitter {
    private val mainHandler = Handler(Looper.getMainLooper())
    var sink: EventChannel.EventSink? = null

    fun emit(state: String, number: String?) {
        val payload = hashMapOf<String, Any?>(
            "state" to state,
            "number" to number,
        )
        mainHandler.post {
            sink?.success(payload)
        }
    }

    fun telephonyStateName(state: Int): String = when (state) {
        TelephonyManager.CALL_STATE_RINGING -> "ringing"
        TelephonyManager.CALL_STATE_OFFHOOK -> "offhook"
        else -> "idle"
    }
}

class PhoneCallTracker(private val context: Context) {
    private val telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
    private var legacyListener: PhoneStateListener? = null
    private var modernCallback: TelephonyCallback? = null
    private var lastNumber: String? = null

    @Suppress("MissingPermission")
    fun start() {
        stop()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val cb = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                override fun onCallStateChanged(state: Int) {
                    val stateName = PhoneCallEmitter.telephonyStateName(state)
                    // Modern API (31+) doesn't provide phone number, use lastNumber
                    if (state == TelephonyManager.CALL_STATE_IDLE) {
                        lastNumber = null
                    }
                    PhoneCallEmitter.emit(stateName, lastNumber)
                }
            }
            modernCallback = cb
            telephony.registerTelephonyCallback(Executors.newSingleThreadExecutor(), cb)
        } else {
            @Suppress("DEPRECATION")
            val listener = object : PhoneStateListener() {
                @Deprecated("Deprecated in Java")
                override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                    // Legacy API (<31) provides phone number
                    if (!phoneNumber.isNullOrBlank()) {
                        lastNumber = phoneNumber
                    }
                    if (state == TelephonyManager.CALL_STATE_IDLE) {
                        lastNumber = null
                    }
                    PhoneCallEmitter.emit(PhoneCallEmitter.telephonyStateName(state), lastNumber)
                }
            }
            legacyListener = listener
            @Suppress("DEPRECATION")
            telephony.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
        }
    }

    fun stop() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            modernCallback?.let { telephony.unregisterTelephonyCallback(it) }
            modernCallback = null
        } else {
            @Suppress("DEPRECATION")
            legacyListener?.let { telephony.listen(it, PhoneStateListener.LISTEN_NONE) }
            legacyListener = null
        }
    }
}
