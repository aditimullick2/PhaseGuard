package com.phaseguard.phaseguard

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer

/**
 * Audio Capture Module for In-Call Recording
 * 
 * Uses AudioRecord with MIC or VOICE_RECOGNITION source to capture room audio
 * when speakerphone is enabled. This allows capturing both sides of a call
 * since the speakerphone audio reaches the microphone.
 * 
 * IMPORTANT: This ONLY works when speakerphone is enabled. Without speakerphone,
 * the earpiece audio doesn't reach the microphone and only user's voice is captured.
 */
class AudioCaptureModule {
    private val TAG = "AudioCaptureModule"
    
    private var context: Context? = null
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    
    // Audio parameters
    private val sampleRate = 16000
    private val channelConfig = AudioFormat.CHANNEL_IN_MONO
    private val audioFormat = AudioFormat.ENCODING_PCM_16BIT
    private val chunkDurationMs = 50 // 50ms chunks
    private val bufferSize: Int
    
    // Test both sources to see which works better
    private val primarySource = MediaRecorder.AudioSource.MIC
    private val fallbackSource = MediaRecorder.AudioSource.VOICE_RECOGNITION
    private var currentSource = primarySource
    
    // For speakerphone detection
    private var audioManager: AudioManager? = null
    private var speakerphoneCheckTimer: Runnable? = null
    private val handler = Handler(Looper.getMainLooper())
    
    // Audio level monitoring
    private var totalAmplitude = 0.0
    private var sampleCount = 0
    
    init {
        bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat) * 2
        Log.i(TAG, "Buffer size: $bufferSize for sample rate: $sampleRate")
    }
    
    fun initialize(context: Context, methodChannel: MethodChannel, eventChannel: EventChannel) {
        this.context = context
        this.methodChannel = methodChannel
        this.eventChannel = eventChannel
        this.audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        // Set up method channel handler
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    checkPermission(result)
                }
                "requestPermission" -> {
                    requestPermission(result)
                }
                "isSpeakerphoneOn" -> {
                    checkSpeakerphone(result)
                }
                "startCapture" -> {
                    val source = call.argument<String>("source")
                    startCapture(source, result)
                }
                "stopCapture" -> {
                    stopCapture(result)
                }
                "getAudioStats" -> {
                    getAudioStats(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Set up event channel for audio chunks
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Log.i(TAG, "Event channel listener attached")
            }
            
            override fun onCancel(arguments: Any?) {
                eventSink = null
                Log.i(TAG, "Event channel listener detached")
            }
        })
        
        Log.i(TAG, "AudioCaptureModule initialized")
    }
    
    private fun checkPermission(result: MethodChannel.Result) {
        val hasPermission = ContextCompat.checkSelfPermission(
            context!!,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        
        result.success(hasPermission)
        Log.i(TAG, "Permission check: $hasPermission")
    }
    
    private fun requestPermission(result: MethodChannel.Result) {
        // In a real app, this would trigger the system permission dialog
        // For now, we return false since we can't show UI from native module
        result.success(false)
        Log.w(TAG, "Permission request should be handled from Flutter side")
    }
    
    private fun checkSpeakerphone(result: MethodChannel.Result) {
        val isOn = audioManager?.isSpeakerphoneOn() ?: false
        result.success(isOn)
        Log.i(TAG, "Speakerphone state: $isOn")
    }
    
    private fun startCapture(source: String?, result: MethodChannel.Result) {
        if (isRecording) {
            result.success(false)
            Log.w(TAG, "Already recording")
            return
        }
        
        // Check permission first
        if (ContextCompat.checkSelfPermission(
                context!!,
                Manifest.permission.RECORD_AUDIO
            ) != PackageManager.PERMISSION_GRANTED) {
            result.success(false)
            Log.e(TAG, "Permission not granted")
            return
        }
        
        // Select audio source
        currentSource = when (source) {
            "VOICE_RECOGNITION" -> fallbackSource
            else -> primarySource
        }
        
        try {
            audioRecord = AudioRecord(
                currentSource,
                sampleRate,
                channelConfig,
                audioFormat,
                bufferSize
            )
            
            if (audioRecord?.state == AudioRecord.STATE_INITIALIZED) {
                audioRecord?.startRecording()
                isRecording = true
                
                // Reset audio stats
                totalAmplitude = 0.0
                sampleCount = 0
                
                // Start audio capture thread
                Thread {
                    captureAudioLoop()
                }.start()
                
                // Start speakerphone monitoring
                startSpeakerphoneMonitoring()
                
                result.success(true)
                Log.i(TAG, "Audio capture started with source: $currentSource")
            } else {
                result.success(false)
                Log.e(TAG, "AudioRecord initialization failed")
            }
        } catch (e: Exception) {
            result.success(false)
            Log.e(TAG, "Error starting capture: ${e.message}")
        }
    }
    
    private fun stopCapture(result: MethodChannel.Result) {
        if (!isRecording) {
            result.success(false)
            Log.w(TAG, "Not recording")
            return
        }
        
        try {
            isRecording = false
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
            
            // Stop speakerphone monitoring
            stopSpeakerphoneMonitoring()
            
            // Report final audio stats
            val avgAmplitude = if (sampleCount > 0) totalAmplitude / sampleCount else 0.0
            Log.i(TAG, "Audio capture stopped. Avg amplitude: $avgAmplitude, samples: $sampleCount")
            
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
            Log.e(TAG, "Error stopping capture: ${e.message}")
        }
    }
    
    private fun captureAudioLoop() {
        val buffer = ByteArray(bufferSize)
        
        while (isRecording) {
            try {
                val bytesRead = audioRecord?.read(buffer, 0, bufferSize) ?: 0
                
                if (bytesRead > 0) {
                    // Calculate audio amplitude for monitoring
                    calculateAmplitude(buffer, bytesRead)
                    
                    // Send audio chunk to Flutter
                    val audioData = buffer.copyOfRange(0, bytesRead)
                    handler.post {
                        eventSink?.success(audioData)
                    }
                    
                    // Log audio level periodically
                    if (sampleCount % 100 == 0) {
                        val avgAmplitude = totalAmplitude / sampleCount
                        Log.d(TAG, "Audio level: avg=$avgAmplitude, bytes=$bytesRead")
                    }
                }
                
                Thread.sleep(chunkDurationMs.toLong())
                
            } catch (e: Exception) {
                Log.e(TAG, "Error in capture loop: ${e.message}")
                break
            }
        }
    }
    
    private fun calculateAmplitude(buffer: ByteArray, length: Int) {
        var sum = 0.0
        for (i in 0 until length step 2) {
            if (i + 1 < length) {
                // Combine two bytes for 16-bit sample
                val sample = ((buffer[i + 1].toInt() and 0xFF) shl 8) or (buffer[i].toInt() and 0xFF)
                // Convert to signed 16-bit
                val signedSample = if (sample >= 32768) sample - 65536 else sample
                sum += kotlin.math.abs(signedSample.toDouble())
            }
        }
        
        val samples = length / 2
        totalAmplitude += sum / samples
        sampleCount++
    }
    
    private fun getAudioStats(result: MethodChannel.Result) {
        val avgAmplitude = if (sampleCount > 0) totalAmplitude / sampleCount else 0.0
        val isSpeakerphoneOn = audioManager?.isSpeakerphoneOn() ?: false
        
        result.success(mapOf(
            "averageAmplitude" to avgAmplitude,
            "totalSamples" to sampleCount,
            "isSpeakerphoneOn" to isSpeakerphoneOn,
            "currentSource" to currentSource.toString()
        ))
    }
    
    private fun startSpeakerphoneMonitoring() {
        speakerphoneCheckTimer = object : Runnable {
            override fun run() {
                if (isRecording) {
                    val isOn = audioManager?.isSpeakerphoneOn() ?: false
                    handler.post {
                        eventSink?.success(mapOf(
                            "type" to "speakerphone_state",
                            "isOn" to isOn
                        ))
                    }
                    
                    // Schedule next check in 1 second
                    handler.postDelayed(this, 1000)
                }
            }
        }
        
        // Start monitoring immediately
        handler.post(speakerphoneCheckTimer!!)
    }
    
    private fun stopSpeakerphoneMonitoring() {
        speakerphoneCheckTimer?.let {
            handler.removeCallbacks(it)
        }
        speakerphoneCheckTimer = null
    }
    
    fun cleanup() {
        stopCapture(object : MethodChannel.Result {
            override fun success(result: Any?) {}
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
            override fun notImplemented() {}
        })
    }
}
