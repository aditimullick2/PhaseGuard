package com.phaseguard.phaseguard

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import io.flutter.plugin.common.MethodChannel

/**
 * Accessibility Service for Call Detection and Audio Capture
 * 
 * NOTE: AccessibilityService primarily provides UI/event access, not direct telephony audio.
 * This service can:
 * - Detect call state changes (incoming, outgoing, ringing)
 * - Identify phone numbers
 * - Attempt system audio capture on some devices (device-dependent)
 * - Does NOT guarantee cellular call audio access on all devices
 */
class CallAccessibilityService : AccessibilityService() {
    private val TAG = "CallAccessibilityService"
    private val CHANNEL = "phaseguard/accessibility_service"
    
    private var telephonyManager: TelephonyManager? = null
    private var audioRecord: AudioRecord? = null
    private var isCapturing = false
    private var callState = TelephonyManager.CALL_STATE_IDLE
    private var phoneNumber: String? = null
    private var sampleRate = 16000
    
    private val handler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null
    
    // Flutter engine reference (set via MainActivity)
    companion object {
        private var flutterMessenger: io.flutter.plugin.common.BinaryMessenger? = null
        
        fun setFlutterMessenger(messenger: io.flutter.plugin.common.BinaryMessenger?) {
            flutterMessenger = messenger
        }
        
        fun getInstance(): CallAccessibilityService? {
            return instance
        }
        
        private var instance: CallAccessibilityService? = null
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.i(TAG, "Accessibility Service created")
        
        // Setup method channel if flutter messenger is available
        flutterMessenger?.let {
            methodChannel = MethodChannel(it, CHANNEL)
        }
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i(TAG, "Accessibility Service connected")
        
        // Initialize telephony manager for call state detection
        telephonyManager = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
        
        // Listen for call state changes
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                telephonyManager?.registerTelephonyCallback(
                    mainExecutor,
                    object : TelephonyCallback(),
                        TelephonyCallback.CallStateListener {
                        override fun onCallStateChanged(state: Int) {
                            handleCallStateChange(state)
                        }
                    }
                )
            } else {
                @Suppress("DEPRECATION")
                telephonyManager?.listen(object : PhoneStateListener() {
                    override fun onCallStateChanged(state: Int, incomingNumber: String?) {
                        phoneNumber = incomingNumber
                        handleCallStateChange(state)
                    }
                }, PhoneStateListener.LISTEN_CALL_STATE)
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException: READ_PHONE_STATE permission might be missing - ${e.message}")
        }
    }
    
    private fun handleCallStateChange(state: Int) {
        callState = state
        
        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                Log.i(TAG, "Call ringing: $phoneNumber")
                notifyFlutter("callRinging", mapOf("phoneNumber" to (phoneNumber ?: "Unknown")))
            }
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                Log.i(TAG, "Call offhook (active): $phoneNumber")
                notifyFlutter("callStarted", mapOf("phoneNumber" to (phoneNumber ?: "Unknown")))
                // Attempt to start audio capture
                attemptAudioCapture()
            }
            TelephonyManager.CALL_STATE_IDLE -> {
                Log.i(TAG, "Call ended")
                notifyFlutter("callEnded", null)
                stopAudioCapture()
            }
        }
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event?.let {
            when (it.eventType) {
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                    // Detect phone UI changes
                    val packageName = it.packageName?.toString()
                    if (packageName != null && 
                        (packageName.contains("com.android.phone") || 
                         packageName.contains("com.android.dialer") ||
                         packageName.contains("com.google.android.dialer"))) {
                        Log.d(TAG, "Phone UI detected: $packageName")
                    }
                }
            }
        }
    }
    
    override fun onInterrupt() {
        Log.i(TAG, "Accessibility Service interrupted")
        stopAudioCapture()
    }
    
    /**
     * Attempt to capture system audio
     * NOTE: This is device-dependent and may not capture cellular call audio
     * on all Android devices. Some devices allow it, others don't.
     */
    private fun attemptAudioCapture() {
        if (isCapturing) return
        
        try {
            val audioSource = MediaRecorder.AudioSource.VOICE_RECOGNITION
            val channelConfig = AudioFormat.CHANNEL_IN_MONO
            val audioFormat = AudioFormat.ENCODING_PCM_16BIT
            
            val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat) * 2
            
            audioRecord = AudioRecord(
                audioSource,
                sampleRate,
                channelConfig,
                audioFormat,
                bufferSize
            )
            
            if (audioRecord?.state == AudioRecord.STATE_INITIALIZED) {
                audioRecord?.startRecording()
                isCapturing = true
                
                // Start audio capture thread
                Thread {
                    captureAudio(bufferSize)
                }.start()
                
                Log.i(TAG, "Audio capture started (Accessibility Service)")
                notifyFlutter("audioCaptureStarted", mapOf("sampleRate" to sampleRate))
            } else {
                Log.w(TAG, "AudioRecord initialization failed (Accessibility Service)")
                notifyFlutter("audioCaptureFailed", mapOf("error" to "AudioRecord initialization failed"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting audio capture: ${e.message}")
            notifyFlutter("audioCaptureFailed", mapOf("error" to e.message))
        }
    }
    
    private fun captureAudio(bufferSize: Int) {
        val buffer = ByteArray(bufferSize)
        
        while (isCapturing) {
            try {
                val bytesRead = audioRecord?.read(buffer, 0, bufferSize) ?: 0
                
                if (bytesRead > 0) {
                    // Send audio data to Flutter
                    val audioData = buffer.copyOfRange(0, bytesRead)
                    notifyFlutter("onAudioData", mapOf("data" to audioData.toList()))
                }
                
                Thread.sleep(10)
                
            } catch (e: Exception) {
                Log.e(TAG, "Error capturing audio: ${e.message}")
                break
            }
        }
    }
    
    private fun stopAudioCapture() {
        if (!isCapturing) return
        
        try {
            isCapturing = false
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
            
            Log.i(TAG, "Audio capture stopped (Accessibility Service)")
            notifyFlutter("audioCaptureStopped", null)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping audio capture: ${e.message}")
        }
    }
    
    private fun notifyFlutter(method: String, data: Map<String, Any?>?) {
        handler.post {
            methodChannel?.invokeMethod(method, data)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopAudioCapture()
        instance = null
        Log.i(TAG, "Accessibility Service destroyed")
    }
    
    // Public methods for Flutter to query state
    fun getCallState(): Int = callState
    fun getPhoneNumber(): String? = phoneNumber
    fun isCapturingAudio(): Boolean = isCapturing
}