package com.phaseguard.phaseguard

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Base64
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Captures live call audio using the privileged VOICE_CALL audio source.
 *
 * Requires android.permission.CAPTURE_AUDIO_OUTPUT — a System/Signature permission
 * that must be granted via ADB (Shizuku/AShell):
 *   pm grant com.phaseguard.phaseguard android.permission.CAPTURE_AUDIO_OUTPUT
 *
 * Once granted this class streams raw PCM-16 at 16kHz to Flutter via EventChannel.
 * Each event is a base64-encoded chunk (~100ms of audio, 3200 bytes).
 *
 * Flutter side: listen to "com.phaseguard/call_audio" EventChannel.
 */
class CallAudioCapture {

    private val SAMPLE_RATE = 16000
    private val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
    private val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

    // VOICE_CALL = 4 captures both downlink (caller) AND uplink (user)
    // VOICE_DOWNLINK = 3 captures caller voice only
    // We default to VOICE_CALL so we can drive STT + PDI for both sides.
    @SuppressLint("InlinedApi")
    private val AUDIO_SOURCE = MediaRecorder.AudioSource.VOICE_CALL

    private var audioRecord: AudioRecord? = null
    private val isRecording = AtomicBoolean(false)
    private var captureJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val bufferSize: Int
        get() = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
            .coerceAtLeast(3200) // ensure at least ~100ms of audio per chunk

    var eventSink: EventChannel.EventSink? = null

    @SuppressLint("MissingPermission")
    fun startCapture(): Boolean {
        if (isRecording.get()) return true

        return try {
            val record = AudioRecord(
                AUDIO_SOURCE,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize * 4 // generous buffer to avoid overruns
            )

            if (record.state != AudioRecord.STATE_INITIALIZED) {
                record.release()
                android.util.Log.e("CallAudioCapture",
                    "AudioRecord failed to initialize. CAPTURE_AUDIO_OUTPUT may not be granted.")
                return false
            }

            audioRecord = record
            record.startRecording()
            isRecording.set(true)

            captureJob = scope.launch {
                val chunk = ByteArray(bufferSize)
                android.util.Log.d("CallAudioCapture",
                    "🎙️ Call audio capture started (VOICE_CALL, 16kHz PCM16)")
                while (isRecording.get()) {
                    val read = record.read(chunk, 0, chunk.size)
                    if (read > 0) {
                        val encoded = Base64.encodeToString(chunk.copyOf(read), Base64.NO_WRAP)
                        withContext(Dispatchers.Main) {
                            eventSink?.success(encoded)
                        }
                    }
                }
            }
            true
        } catch (e: SecurityException) {
            android.util.Log.e("CallAudioCapture",
                "SecurityException: CAPTURE_AUDIO_OUTPUT not granted. " +
                "Run: pm grant com.phaseguard.phaseguard android.permission.CAPTURE_AUDIO_OUTPUT", e)
            false
        } catch (e: Exception) {
            android.util.Log.e("CallAudioCapture", "Failed to start call audio capture", e)
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
        android.util.Log.d("CallAudioCapture", "🛑 Call audio capture stopped")
    }

    fun isActive(): Boolean = isRecording.get()
}
