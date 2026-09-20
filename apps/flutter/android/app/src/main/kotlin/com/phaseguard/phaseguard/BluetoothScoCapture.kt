package com.phaseguard.phaseguard

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * Bluetooth SCO Audio Capture
 * 
 * Captures audio from Bluetooth SCO (Synchronous Connection-Oriented) channel.
 * This is used for telephone-quality audio during calls when using a Bluetooth headset.
 * 
 * NOTES:
 * - Requires Bluetooth headset to be connected
 * - Audio quality is limited to telephone range (8-16 kHz)
 * - Works best during active calls
 * - Some devices may not support SCO audio capture
 */
class BluetoothScoCapture {
    private val TAG = "BluetoothScoCapture"
    private val CHANNEL = "phaseguard/bluetooth_sco"
    
    private var audioManager: AudioManager? = null
    private var audioRecord: AudioRecord? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothHeadset: BluetoothHeadset? = null
    private var isCapturing = false
    private var isScoConnected = false
    private var sampleRate = 16000
    
    private val handler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null
    
    // Bluetooth headset profile listener
    private val headsetProfileListener = object : BluetoothProfile.ServiceListener {
        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
            if (profile == BluetoothProfile.HEADSET) {
                bluetoothHeadset = proxy as BluetoothHeadset
                Log.i(TAG, "Bluetooth headset connected")
                checkScoConnection()
            }
        }
        
        override fun onServiceDisconnected(profile: Int) {
            if (profile == BluetoothProfile.HEADSET) {
                bluetoothHeadset = null
                isScoConnected = false
                Log.i(TAG, "Bluetooth headset disconnected")
                notifyFlutter("headsetDisconnected", null)
            }
        }
    }
    
    fun initialize(context: Context, messenger: io.flutter.plugin.common.BinaryMessenger) {
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        methodChannel = MethodChannel(messenger, CHANNEL)

        // Register headset profile listener (with permission check)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                bluetoothAdapter?.getProfileProxy(context, headsetProfileListener, BluetoothProfile.HEADSET)
            } else {
                bluetoothAdapter?.getProfileProxy(context, headsetProfileListener, BluetoothProfile.HEADSET)
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Bluetooth permission not granted during initialization: ${e.message}")
        }

        Log.i(TAG, "Bluetooth SCO capture initialized")
    }
    
    fun setMethodCallHandler(handler: MethodChannel.MethodCallHandler) {
        methodChannel?.setMethodCallHandler(handler)
    }
    
    private fun checkScoConnection() {
        try {
            val connected = bluetoothHeadset?.connectedDevices?.isNotEmpty() == true
            isScoConnected = connected

            if (connected) {
                notifyFlutter("headsetConnected", mapOf(
                    "deviceName" to bluetoothHeadset?.connectedDevices?.firstOrNull()?.name
                ))
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Bluetooth permission not granted: ${e.message}")
            isScoConnected = false
        }
    }
    
    fun isHeadsetConnected(): Boolean {
        return try {
            bluetoothHeadset?.connectedDevices?.isNotEmpty() == true
        } catch (e: SecurityException) {
            Log.e(TAG, "Bluetooth permission not granted: ${e.message}")
            false
        }
    }
    
    fun isScoAvailable(): Boolean {
        return isHeadsetConnected()
    }
    
    /**
     * Start SCO audio capture
     * Must be called during an active call for best results
     */
    fun startScoCapture(sampleRate: Int, result: MethodChannel.Result) {
        if (isCapturing) {
            result.success(true)
            return
        }
        
        if (!isScoAvailable()) {
            result.success(false)
            return
        }
        
        try {
            this.sampleRate = sampleRate
            
            // Start SCO connection
            audioManager?.startBluetoothSco()
            audioManager?.isBluetoothScoOn = true
            
            // Wait for SCO to connect
            Thread.sleep(500)
            
            if (audioManager?.isBluetoothScoOn == true) {
                startAudioRecording()
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting SCO capture: ${e.message}")
            result.success(false)
        }
    }
    
    private fun startAudioRecording() {
        try {
            val audioSource = AudioManager.STREAM_VOICE_CALL
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
                
                Log.i(TAG, "SCO audio capture started")
                notifyFlutter("scoCaptureStarted", mapOf("sampleRate" to sampleRate))
            } else {
                Log.e(TAG, "AudioRecord initialization failed for SCO")
                notifyFlutter("scoCaptureFailed", mapOf("error" to "AudioRecord initialization failed"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting audio recording: ${e.message}")
            notifyFlutter("scoCaptureFailed", mapOf("error" to e.message))
        }
    }
    
    private fun captureAudio(bufferSize: Int) {
        val buffer = ByteArray(bufferSize)
        
        while (isCapturing) {
            try {
                val bytesRead = audioRecord?.read(buffer, 0, bufferSize) ?: 0
                
                if (bytesRead > 0) {
                    val audioData = buffer.copyOfRange(0, bytesRead)
                    notifyFlutter("onScoAudioData", mapOf("data" to audioData.toList()))
                }
                
                Thread.sleep(10)
                
            } catch (e: Exception) {
                Log.e(TAG, "Error capturing SCO audio: ${e.message}")
                break
            }
        }
    }
    
    fun stopScoCapture(result: MethodChannel.Result) {
        try {
            isCapturing = false
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
            
            audioManager?.stopBluetoothSco()
            audioManager?.isBluetoothScoOn = false
            
            Log.i(TAG, "SCO audio capture stopped")
            notifyFlutter("scoCaptureStopped", null)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping SCO capture: ${e.message}")
            result.success(false)
        }
    }
    
    fun getDeviceInfo(result: MethodChannel.Result) {
        val info = mapOf(
            "headsetConnected" to isHeadsetConnected(),
            "scoAvailable" to isScoAvailable(),
            "scoOn" to (audioManager?.isBluetoothScoOn == true),
            "deviceName" to bluetoothHeadset?.connectedDevices?.firstOrNull()?.name,
            "sampleRate" to sampleRate
        )
        result.success(info)
    }
    
    private fun notifyFlutter(method: String, data: Map<String, Any?>?) {
        handler.post {
            methodChannel?.invokeMethod(method, data)
        }
    }
    
    fun cleanup() {
        stopScoCapture(object : MethodChannel.Result {
            override fun success(result: Any?) {}
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
            override fun notImplemented() {}
        })
        
        bluetoothAdapter?.closeProfileProxy(BluetoothProfile.HEADSET, bluetoothHeadset)
        bluetoothHeadset = null
    }
}