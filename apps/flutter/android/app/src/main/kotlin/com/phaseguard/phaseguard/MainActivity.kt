package com.phaseguard.phaseguard

import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.telecom.TelecomManager
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val TAG = "ScreenAudioCapture"
    private val CHANNEL = "phaseguard/screen_audio"
    private val DIALER_CHANNEL = "phaseguard/dialer"
    private val INCALL_CHANNEL = "phaseguard/incall_service"
    private val PHONE_STATE_CHANNEL = "phaseguard/phone_state"
    private val PHONE_CONTROL_CHANNEL = "phaseguard/phone_control"
    private val CALL_AUDIO_CHANNEL = "com.phaseguard/call_audio"
    private val AUDIO_CONTROL_CHANNEL = "com.phaseguard/audio"
    private val BLUETOOTH_CHANNEL = "phaseguard/bluetooth_sco"

    private var mediaProjectionManager: MediaProjectionManager? = null
    private var sampleRate = 16000
    private var methodChannel: MethodChannel? = null
    private var dialerMethodChannel: MethodChannel? = null
    private var inCallMethodChannel: MethodChannel? = null
    private var phoneControlMethodChannel: MethodChannel? = null
    private var audioControlMethodChannel: MethodChannel? = null

    private var isCapturing = false

    private var audioCaptureModule: AudioCaptureModule? = null

    // Phone call monitoring for remote audio capture
    private var tracker: PhoneCallTracker? = null
    private var speakerphoneService: SpeakerphoneAudioService? = null
    private var callAudioEventSink: EventChannel.EventSink? = null

    // TelecomManager for call handling
    private var telecomManager: TelecomManager? = null

    // Pending result for role/dialer request
    private var pendingDialerResult: MethodChannel.Result? = null

    // Coroutine scope for async operations
    private val coroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize TelecomManager
        telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        
        // Handle dialer intents
        handleDialerIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleDialerIntent(intent)
    }
    
    private fun handleDialerIntent(intent: Intent?) {
        intent?.let {
            when (it.action) {
                Intent.ACTION_DIAL, Intent.ACTION_CALL -> {
                    val phoneNumber = it.data?.schemeSpecificPart
                    if (phoneNumber != null) {
                        // Notify Flutter about the dial request
                        Log.d(TAG, "Dial request for: $phoneNumber")
                        
                        // Store phone number for later use
                        // This can be sent to Flutter via method channel when needed
                        // methodChannel?.invokeMethod("onDialRequest", mapOf("phoneNumber" to phoneNumber))
                    }
                }
            }
        }
    }
    
    private fun answerIncomingCall(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                telecomManager?.acceptRingingCall()
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error answering call: ${e.message}")
            false
        }
    }
    
    /**
     * Checks whether PhaseGuard is currently the default phone/dialer app.
     */
    private fun isDefaultDialer(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as? RoleManager
            roleManager?.isRoleHeld(RoleManager.ROLE_DIALER) == true
        } else {
            val tm = telecomManager ?: return false
            packageName == tm.defaultDialerPackage
        }
    }
    
    /**
     * Requests that the system prompt the user to set PhaseGuard as the default dialer.
     * On Android 10+ (Q) this uses the RoleManager API; on older versions it falls back to
     * TelecomManager.ACTION_CHANGE_DEFAULT_DIALER.
     */
    private fun requestDefaultDialer(result: MethodChannel.Result) {
        if (isDefaultDialer()) {
            result.success(mapOf("alreadyDefault" to true, "requested" to false))
            return
        }
        pendingDialerResult = result
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER)
                startActivityForResult(intent, REQUEST_DEFAULT_DIALER_CODE)
            } else {
                val intent = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER).apply {
                    putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, packageName)
                }
                startActivityForResult(intent, REQUEST_DEFAULT_DIALER_CODE)
            }
        } catch (e: Exception) {
            pendingDialerResult = null
            Log.e(TAG, "Error requesting default dialer: ${e.message}")
            result.error("DIALER_ERROR", "Failed to request default dialer: ${e.message}", null)
        }
    }
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set flutter messenger for Accessibility Service
        CallAccessibilityService.setFlutterMessenger(flutterEngine.dartExecutor.binaryMessenger)
        
        // Set flutter messenger for InCallService
        PhaseGuardInCallService.setFlutterMessenger(flutterEngine.dartExecutor.binaryMessenger)
        
        // --- Dialer Channel ---
        dialerMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DIALER_CHANNEL)
        dialerMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isDefaultDialer" -> result.success(isDefaultDialer())
                "requestDefaultDialer" -> requestDefaultDialer(result)
                else -> result.notImplemented()
            }
        }
        
        // --- InCall Service Control Channel ---
        inCallMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INCALL_CHANNEL)
        inCallMethodChannel?.setMethodCallHandler { call, result ->
            val service = PhaseGuardInCallService.getInstance()
            if (service == null) {
                result.error("NO_SERVICE", "InCallService is not active", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "answerCall" -> result.success(service.answerCall())
                "rejectCall" -> result.success(service.rejectCall())
                "disconnectCall" -> result.success(service.disconnectCall())
                "hasActiveCall" -> result.success(service.getCurrentCall() != null)
                else -> result.notImplemented()
            }
        }
        
        // Initialize Bluetooth SCO capture (disabled - not required for Agora audio capture)
        // Bluetooth SCO capture is optional and requires runtime permissions
        // bluetoothScoCapture = BluetoothScoCapture()
        // bluetoothScoCapture?.initialize(this, flutterEngine.dartExecutor.binaryMessenger!!)

        // Shizuku audio capture disabled - not in scope for current implementation
        // shizukuAudioCapture = ShizukuAudioCapture()
        // shizukuAudioCapture?.initialize(flutterEngine.dartExecutor.binaryMessenger!!, this)

        // Recording Priority Manager disabled - not in scope for current implementation
        // recordingPriorityManager = RecordingPriorityManager(this)
        // recordingPriorityManager?.initialize(flutterEngine.dartExecutor.binaryMessenger)

        // Initialize Audio Capture Module for in-call recording
        audioCaptureModule = AudioCaptureModule()
        val audioCaptureMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "phaseguard/audio_capture")
        val audioCaptureEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "phaseguard/audio_capture_events")
        audioCaptureModule?.initialize(this, audioCaptureMethodChannel, audioCaptureEventChannel)

        // ── Phone state events ──────────────────────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PHONE_STATE_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    PhoneCallEmitter.sink = events
                }
                override fun onCancel(arguments: Any?) {
                    PhoneCallEmitter.sink = null
                }
            })

        // ── Phone control methods ───────────────────────────────────────────────
        phoneControlMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PHONE_CONTROL_CHANNEL)
        phoneControlMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitor" -> {
                    startMonitor()
                    result.success(true)
                }
                "stopMonitor" -> {
                    stopMonitor()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── Call audio capture stream (speakerphone fallback) ────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_AUDIO_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    callAudioEventSink = events
                    // Start speakerphone service
                    val intent = Intent(this@MainActivity, SpeakerphoneAudioService::class.java)
                    startService(intent)
                    speakerphoneService = SpeakerphoneAudioService.getInstance()
                    speakerphoneService?.setAudioCallback { chunk ->
                        try {
                            val encoded = android.util.Base64.encodeToString(chunk, android.util.Base64.NO_WRAP)
                            callAudioEventSink?.success(encoded)
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Failed to send audio chunk", e)
                        }
                    }
                }
                override fun onCancel(arguments: Any?) {
                    callAudioEventSink = null
                    speakerphoneService?.stopCapture()
                }
            })

        // ── Audio control: start/stop call capture + speakerphone toggle ────────
        audioControlMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CONTROL_CHANNEL)
        audioControlMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startCallCapture" -> {
                    if (speakerphoneService == null) {
                        speakerphoneService = SpeakerphoneAudioService.getInstance()
                    }
                    val started = speakerphoneService?.startCapture() ?: false
                    result.success(started)
                }
                "stopCallCapture" -> {
                    speakerphoneService?.stopCapture()
                    result.success(true)
                }
                "isCallCaptureActive" -> {
                    result.success(speakerphoneService?.isCapturing() ?: false)
                }
                "setSpeakerphone" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    try {
                        val am = getSystemService(AUDIO_SERVICE) as android.media.AudioManager
                        am.isSpeakerphoneOn = on
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("AUDIO_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermissionAndStart" -> {
                    val requestedSampleRate = call.argument<Int>("sampleRate") ?: 16000
                    requestPermissionAndStart(requestedSampleRate, result)
                }
                "stopCapture" -> {
                    stopCapture(result)
                }
                "isAvailable" -> {
                    isAvailable(result)
                }
                "getDeviceInfo" -> {
                    getDeviceInfo(result)
                }
                "isAccessibilityServiceEnabled" -> {
                    isAccessibilityServiceEnabled(result)
                }
                "enableAccessibilityService" -> {
                    enableAccessibilityService(result)
                }
                "getAccessibilityServiceState" -> {
                    getAccessibilityServiceState(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        ScreenCaptureService.onAudioDataListener = { data ->
            runOnUiThread {
                methodChannel?.invokeMethod("onAudioData", mapOf("data" to data.toList()))
            }
        }
        
        ScreenCaptureService.onCaptureErrorListener = { error ->
            runOnUiThread {
                methodChannel?.invokeMethod("onCaptureError", mapOf("error" to error))
                isCapturing = false
            }
        }
        
        ScreenCaptureService.onCaptureStoppedListener = {
            runOnUiThread {
                methodChannel?.invokeMethod("onCaptureStopped", null)
                isCapturing = false
            }
        }
        
        // Bluetooth SCO method channel (disabled - not required for Agora audio capture)
        // Bluetooth SCO capture is optional and requires runtime permissions
        // Not needed for Agora AudioFrameObserver audio capture
        /*
        val bluetoothMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLUETOOTH_CHANNEL)
        bluetoothMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startScoCapture" -> {
                    val requestedSampleRate = call.argument<Int>("sampleRate") ?: 16000
                    bluetoothScoCapture?.startScoCapture(requestedSampleRate, result)
                }
                "stopScoCapture" -> {
                    bluetoothScoCapture?.stopScoCapture(result)
                }
                "getScoDeviceInfo" -> {
                    bluetoothScoCapture?.getDeviceInfo(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        */

        // Shizuku method channel disabled - not in scope for current implementation
        /*
        val shizukuChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "phaseguard/shizuku_audio")
        shizukuChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getShizukuState" -> {
                    shizukuAudioCapture?.getShizukuState(result)
                }
                "requestShizukuPermission" -> {
                    shizukuAudioCapture?.requestShizukuPermission(result)
                }
                "startElevatedCapture" -> {
                    val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                    shizukuAudioCapture?.startElevatedCapture(
                        null,
                        Activity.RESULT_CANCELED,
                        null,
                        sampleRate,
                        result
                    )
                }
                "stopElevatedCapture" -> {
                    shizukuAudioCapture?.stopElevatedCapture(result)
                }
                "runSelfTest" -> {
                    shizukuAudioCapture?.runSelfTest(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        */

        // Recording Priority Manager method channel disabled - not in scope for current implementation
        /*
        val priorityChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "phaseguard/priority_recording")
        priorityChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startPriorityRecording" -> {
                    val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                    coroutineScope.launch {
                        val recordingResult = recordingPriorityManager?.startRecording(sampleRate)
                        result.success(mapOf(
                            "success" to recordingResult?.success,
                            "method" to recordingResult?.method?.name,
                            "message" to recordingResult?.message,
                            "health" to recordingResult?.health,
                            "speakerphoneEnabled" to recordingResult?.speakerphoneEnabled,
                            "hardwareRecommended" to recordingResult?.hardwareRecommended,
                            "hardwareOptions" to recordingResult?.hardwareOptions
                        ))
                    }
                }
                "stopPriorityRecording" -> {
                    coroutineScope.launch {
                        val recordingResult = recordingPriorityManager?.stopRecording()
                        result.success(mapOf(
                            "success" to recordingResult?.success,
                            "method" to recordingResult?.method?.name,
                            "message" to recordingResult?.message
                        ))
                    }
                }
                "getRecordingStatus" -> {
                    val status = recordingPriorityManager?.getRecordingStatus()
                    result.success(status)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        */
    }
    
    private fun requestPermissionAndStart(sampleRate: Int, result: MethodChannel.Result) {
        if (isCapturing) {
            result.success(true)
            return
        }
        
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        
        val intent = mediaProjectionManager?.createScreenCaptureIntent()
        
        try {
            startActivityForResult(intent, SCREEN_CAPTURE_REQUEST_CODE)
            this.sampleRate = sampleRate
            // Store the result callback to call after permission is granted
            pendingResult = result
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting screen capture: ${e.message}")
            result.success(false)
        }
    }
    
    private var pendingResult: MethodChannel.Result? = null
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        when (requestCode) {
            SCREEN_CAPTURE_REQUEST_CODE -> {
                val result = pendingResult
                pendingResult = null
                
                if (resultCode == Activity.RESULT_OK && data != null) {
                    try {
                        val intent = Intent(this, ScreenCaptureService::class.java).apply {
                            putExtra("RESULT_CODE", resultCode)
                            putExtra("DATA_INTENT", data)
                            putExtra("SAMPLE_RATE", sampleRate)
                        }
                        
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        
                        isCapturing = true
                        result?.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error starting ScreenCaptureService: ${e.message}")
                        result?.success(false)
                    }
                } else {
                    result?.success(false)
                }
            }
            REQUEST_DEFAULT_DIALER_CODE -> {
                val result = pendingDialerResult
                pendingDialerResult = null
                val isNowDefault = isDefaultDialer()
                Log.d(TAG, "Default dialer result: resultCode=$resultCode, isDefault=$isNowDefault")
                result?.success(mapOf(
                    "alreadyDefault" to false,
                    "requested" to true,
                    "granted" to (resultCode == Activity.RESULT_OK || isNowDefault)
                ))
            }
        }
    }
    
    private fun stopCapture(result: MethodChannel.Result) {
        try {
            val intent = Intent(this, ScreenCaptureService::class.java).apply {
                action = "STOP"
            }
            startService(intent)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping capture: ${e.message}")
            result.success(false)
        }
    }
    
    private fun isAvailable(result: MethodChannel.Result) {
        // Screen audio capture is available on most Android 5.0+ devices
        val available = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP
        result.success(available)
    }
    
    private fun getDeviceInfo(result: MethodChannel.Result) {
        val info = mapOf(
            "available" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP),
            "sdk_int" to Build.VERSION.SDK_INT,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "android_version" to Build.VERSION.RELEASE
        )
        result.success(info)
    }
    
    private fun isAccessibilityServiceEnabled(result: MethodChannel.Result) {
        val service = CallAccessibilityService.getInstance()
        result.success(service != null)
    }
    
    private fun enableAccessibilityService(result: MethodChannel.Result) {
        try {
            val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening accessibility settings: ${e.message}")
            result.success(false)
        }
    }
    
    private fun getAccessibilityServiceState(result: MethodChannel.Result) {
        val service = CallAccessibilityService.getInstance()
        val state = mapOf(
            "enabled" to (service != null),
            "callState" to service?.getCallState(),
            "phoneNumber" to service?.getPhoneNumber(),
            "isCapturing" to service?.isCapturingAudio()
        )
        result.success(state)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopCapture(object : MethodChannel.Result {
            override fun success(result: Any?) {}
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
            override fun notImplemented() {}
        })
        audioCaptureModule?.cleanup()

        // Cleanup phone monitoring
        speakerphoneService?.stopCapture()
        stopService(Intent(this, SpeakerphoneAudioService::class.java))
        stopMonitor()
    }

    // ── Phone Monitoring Methods ───────────────────────────────────────────────

    private fun emitFromIntent(intent: Intent?) {
        val state = intent?.getStringExtra(CallMonitorService.EXTRA_STATE) ?: return
        val number = intent.getStringExtra(CallMonitorService.EXTRA_NUMBER)
        PhoneCallEmitter.emit(state, number)
    }

    private fun startMonitor() {
        if (tracker == null) {
            tracker = PhoneCallTracker(this).also { it.start() }
        }
        val service = Intent(this, CallMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(service)
        } else {
            startService(service)
        }
    }

    private fun stopMonitor() {
        tracker?.stop()
        tracker = null
        stopService(Intent(this, CallMonitorService::class.java))
    }
    
    companion object {
        private const val SCREEN_CAPTURE_REQUEST_CODE = 1001
        private const val REQUEST_DEFAULT_DIALER_CODE = 1002
    }
}
