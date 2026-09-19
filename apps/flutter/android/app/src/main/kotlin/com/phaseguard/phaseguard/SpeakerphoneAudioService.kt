package com.phaseguard.phaseguard

import android.annotation.SuppressLint
import android.app.Service
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Base64
import android.util.Log
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Speakerphone fallback audio capture service.
 * When Shizuku VOICE_CALL returns silence or isn't available,
 * this service uses AudioSource.MIC in speakerphone mode as a fallback.
 *
 * Works on every phone with no special access. Audio quality is lower
 * but suitable for 300–3400 Hz scam detection DSP pipeline.
 */
class SpeakerphoneAudioService : Service() {
    private val SAMPLE_RATE = 16000
    private val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
    private val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    private val AUDIO_SOURCE = MediaRecorder.AudioSource.MIC

    private var audioRecord: AudioRecord? = null
    private val isRecording = AtomicBoolean(false)
    private var captureJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private var audioCallback: ((ByteArray) -> Unit)? = null
    private var errorCallback: ((String) -> Unit)? = null

    private val bufferSize: Int
        get() = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
            .coerceAtLeast(3200)

    companion object {
        private var instance: SpeakerphoneAudioService? = null
        fun getInstance(): SpeakerphoneAudioService? = instance
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d("SpeakerphoneAudioService", "Service created")
    }

    override fun onBind(intent: Intent?) = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("SpeakerphoneAudioService", "Service started")
        return START_STICKY
    }

    fun setAudioCallback(callback: (ByteArray) -> Unit) {
        audioCallback = callback
    }

    fun setErrorCallback(callback: (String) -> Unit) {
        errorCallback = callback
    }

    @SuppressLint("MissingPermission")
    fun startCapture(): Boolean {
        if (isRecording.get()) return true

        return try {
            // Ensure AudioManager has speakerphone enabled
            val am = getSystemService(AUDIO_SERVICE) as android.media.AudioManager
            am.isSpeakerphoneOn = true
            Log.d("SpeakerphoneAudioService", "🔊 Speakerphone enabled for fallback capture")

            val record = AudioRecord(
                AUDIO_SOURCE,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize * 4
            )

            if (record.state != AudioRecord.STATE_INITIALIZED) {
                record.release()
                Log.e("SpeakerphoneAudioService", "AudioRecord failed to initialize")
                errorCallback?.invoke("AudioRecord initialization failed")
                return false
            }

            audioRecord = record
            record.startRecording()
            isRecording.set(true)

            captureJob = scope.launch {
                val chunk = ByteArray(bufferSize)
                Log.d("SpeakerphoneAudioService", "🎙️ Speakerphone mic capture started (MIC, 16kHz PCM16)")
                while (isRecording.get()) {
                    val read = record.read(chunk, 0, chunk.size)
                    if (read > 0) {
                        val audioChunk = chunk.copyOf(read)
                        withContext(Dispatchers.Main) {
                            audioCallback?.invoke(audioChunk)
                        }
                    }
                }
            }
            true
        } catch (e: SecurityException) {
            Log.e("SpeakerphoneAudioService", "RECORD_AUDIO permission not granted", e)
            errorCallback?.invoke("RECORD_AUDIO permission denied")
            false
        } catch (e: Exception) {
            Log.e("SpeakerphoneAudioService", "Failed to start capture", e)
            errorCallback?.invoke(e.message ?: "Unknown error")
            false
        }
    }

    fun stopCapture() {
        isRecording.set(false)
        captureJob?.cancel()
        captureJob = null
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (_: Exception) {}
        audioRecord = null
        Log.d("SpeakerphoneAudioService", "🛑 Speakerphone capture stopped")
    }

    fun isCapturing(): Boolean = isRecording.get()

    override fun onDestroy() {
        stopCapture()
        scope.cancel()
        instance = null
        super.onDestroy()
    }
}
