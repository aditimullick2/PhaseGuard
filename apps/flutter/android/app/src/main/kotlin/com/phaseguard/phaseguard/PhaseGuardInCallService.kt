package com.phaseguard.phaseguard

import android.telecom.InCallService
import android.telecom.Call
import android.telecom.VideoProfile
import android.util.Log
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class PhaseGuardInCallService : InCallService() {
    private val TAG = "PhaseGuardInCallService"
    private var currentCall: Call? = null
    
    companion object {
        private var flutterMessenger: BinaryMessenger? = null
        private var methodChannel: MethodChannel? = null
        
        // Singleton so MainActivity can call answerCall/rejectCall/disconnectCall
        private var instance: PhaseGuardInCallService? = null
        fun getInstance(): PhaseGuardInCallService? = instance
        
        fun setFlutterMessenger(messenger: BinaryMessenger) {
            flutterMessenger = messenger
            // Outbound channel: native → Flutter (call events)
            methodChannel = MethodChannel(messenger, "phaseguard/incall_service")
            // Inbound control (answerCall etc.) is handled in MainActivity.configureFlutterEngine
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "PhaseGuardInCallService created")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "PhaseGuardInCallService destroyed")
    }
    
    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        Log.d(TAG, "Call added: ${call.details}")
        currentCall = call
        
        // Register callback to listen to call state changes
        call.registerCallback(callCallback)
        
        // Notify Flutter about the incoming call
        val phoneNumber = runCatching { call.details.handle?.schemeSpecificPart }.getOrNull() ?: ""
        methodChannel?.invokeMethod("onCallAdded", mapOf(
            "phoneNumber" to phoneNumber,
            "callState" to call.details.state.toString()
        ))
    }
    
    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        Log.d(TAG, "Call removed: ${call.details}")
        call.unregisterCallback(callCallback)
        
        if (currentCall == call) {
            currentCall = null
            
            // Notify Flutter about the call ending
            methodChannel?.invokeMethod("onCallRemoved", null)
        }
    }
    
    private val callCallback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            super.onStateChanged(call, state)
            Log.d(TAG, "Call state changed: $state")
            
            val phoneNumber = runCatching { call.details.handle?.schemeSpecificPart }.getOrNull() ?: ""
            // Notify Flutter about state changes
            methodChannel?.invokeMethod("onCallStateChanged", mapOf(
                "state" to state,
                "phoneNumber" to phoneNumber
            ))
        }
    }
    
    fun getCurrentCall(): Call? = currentCall
    
    fun answerCall(): Boolean {
        return try {
            currentCall?.answer(VideoProfile.STATE_AUDIO_ONLY)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error answering call: ${e.message}")
            false
        }
    }
    
    fun rejectCall(): Boolean {
        return try {
            currentCall?.reject(false, null)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error rejecting call: ${e.message}")
            false
        }
    }
    
    fun disconnectCall(): Boolean {
        return try {
            currentCall?.disconnect()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error disconnecting call: ${e.message}")
            false
        }
    }
}