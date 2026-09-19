package com.phaseguard.phaseguard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

class ScreenCaptureService : Service() {
    private val TAG = "ScreenCaptureService"
    private val CHANNEL_ID = "ScreenCaptureChannel"
    
    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var audioRecord: AudioRecord? = null
    
    @Volatile private var isCapturing = false
    private var sampleRate = 16000

    companion object {
        var onAudioDataListener: ((ByteArray) -> Unit)? = null
        var onCaptureErrorListener: ((String) -> Unit)? = null
        var onCaptureStoppedListener: (() -> Unit)? = null
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == "STOP") {
            stopCapture()
            stopSelf()
            return START_NOT_STICKY
        }

        val resultCode = intent?.getIntExtra("RESULT_CODE", 0) ?: 0
        val dataIntent = intent?.getParcelableExtra<Intent>("DATA_INTENT")
        sampleRate = intent?.getIntExtra("SAMPLE_RATE", 16000) ?: 16000

        if (resultCode == 0 || dataIntent == null) {
            Log.e(TAG, "Invalid intent data for ScreenCaptureService")
            stopSelf()
            return START_NOT_STICKY
        }

        startForegroundService()

        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = mediaProjectionManager?.getMediaProjection(resultCode, dataIntent)

        if (mediaProjection != null) {
            startAudioCapture()
        } else {
            onCaptureErrorListener?.invoke("Failed to get MediaProjection")
            stopSelf()
        }

        return START_NOT_STICKY
    }

    private fun startForegroundService() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PhaseGuard Recording")
            .setContentText("Capturing system audio")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now) // Use a default icon or app icon
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceCompat.startForeground(
                this,
                1,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(1, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Screen Capture Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun startAudioCapture() {
        try {
            val channelConfig = AudioFormat.CHANNEL_IN_MONO
            val audioFormat = AudioFormat.ENCODING_PCM_16BIT
            val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat) * 2

            val audioRecordBuilder = AudioRecord.Builder()
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(audioFormat)
                        .setSampleRate(sampleRate)
                        .setChannelMask(channelConfig)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val playbackConfig = AudioPlaybackCaptureConfiguration.Builder(mediaProjection!!)
                    .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                    .addMatchingUsage(AudioAttributes.USAGE_GAME)
                    .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                    .build()
                audioRecordBuilder.setAudioPlaybackCaptureConfig(playbackConfig)
            } else {
                // Fallback for older devices, although AudioPlaybackCapture is Q+.
                // Without it, MediaProjection audio isn't supported the same way.
                onCaptureErrorListener?.invoke("Audio playback capture requires Android 10+")
                stopSelf()
                return
            }

            audioRecord = audioRecordBuilder.build()

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                onCaptureErrorListener?.invoke("AudioRecord initialization failed")
                stopSelf()
                return
            }

            audioRecord?.startRecording()
            isCapturing = true

            Thread {
                captureAudio(bufferSize)
            }.start()

            Log.i(TAG, "Audio capture started successfully")

        } catch (e: Exception) {
            Log.e(TAG, "Error starting audio capture: ${e.message}")
            onCaptureErrorListener?.invoke(e.message ?: "Unknown error")
            isCapturing = false
            stopSelf()
        }
    }

    private fun captureAudio(bufferSize: Int) {
        val buffer = ByteArray(bufferSize)
        while (isCapturing) {
            try {
                val bytesRead = audioRecord?.read(buffer, 0, bufferSize) ?: 0
                if (bytesRead > 0) {
                    val audioData = buffer.copyOfRange(0, bytesRead)
                    onAudioDataListener?.invoke(audioData)
                }
                Thread.sleep(10)
            } catch (e: Exception) {
                Log.e(TAG, "Error capturing audio: ${e.message}")
                break
            }
        }
    }

    private fun stopCapture() {
        isCapturing = false
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {}
        audioRecord = null
        
        try {
            mediaProjection?.stop()
        } catch (e: Exception) {}
        mediaProjection = null
        
        onCaptureStoppedListener?.invoke()
    }

    override fun onDestroy() {
        stopCapture()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
