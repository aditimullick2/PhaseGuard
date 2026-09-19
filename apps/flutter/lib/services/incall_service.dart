import 'dart:async';

import 'package:flutter/services.dart';

/// Represents the state of the currently active call.
enum InCallState {
  /// No active call.
  idle,

  /// Call is ringing (incoming).
  ringing,

  /// Call is active (connected).
  active,

  /// Call is on hold.
  holding,

  /// Call is disconnecting.
  disconnecting,

  /// Unknown / other state.
  unknown,
}

/// Event emitted by [InCallService] when call state changes.
class CallEvent {
  final String type; // 'callAdded', 'callRemoved', 'callStateChanged'
  final String phoneNumber;
  final InCallState state;

  const CallEvent({
    required this.type,
    required this.phoneNumber,
    required this.state,
  });

  @override
  String toString() =>
      'CallEvent(type: $type, number: $phoneNumber, state: $state)';
}

/// Wraps the Android [InCallService] and Default Dialer API.
///
/// **Setup:**
/// Call [startListening] once (e.g. in `initState`) and [dispose] when done.
///
/// **Default Dialer:**
/// Use [requestDefaultDialer] to prompt the user to set PhaseGuard as the
/// default phone app. Use [isDefaultDialer] to check the current status.
///
/// **Call control:**
/// [answerCall], [rejectCall], [disconnectCall] only work while
/// PhaseGuard is the default dialer (InCallService is active).
class InCallService {
  static const MethodChannel _inCallChannel =
      MethodChannel('phaseguard/incall_service');
  static const MethodChannel _dialerChannel =
      MethodChannel('phaseguard/dialer');

  final StreamController<CallEvent> _eventController =
      StreamController<CallEvent>.broadcast();

  /// Stream of [CallEvent]s fired whenever call state changes.
  Stream<CallEvent> get callEvents => _eventController.stream;

  String? _currentPhoneNumber;
  InCallState _currentState = InCallState.idle;

  String? get currentPhoneNumber => _currentPhoneNumber;
  InCallState get currentState => _currentState;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Start listening to call events from the native [InCallService].
  void startListening() {
    _inCallChannel.setMethodCallHandler(_handleNativeCall);
  }

  /// Stop listening. Call this in [dispose].
  void stopListening() {
    _inCallChannel.setMethodCallHandler(null);
  }

  void dispose() {
    stopListening();
    _eventController.close();
  }

  // ---------------------------------------------------------------------------
  // Default Dialer API
  // ---------------------------------------------------------------------------

  /// Returns `true` if PhaseGuard is currently the default phone app.
  Future<bool> isDefaultDialer() async {
    try {
      final result = await _dialerChannel.invokeMethod<bool>('isDefaultDialer');
      return result ?? false;
    } on PlatformException catch (e) {
      _log('isDefaultDialer error: ${e.message}');
      return false;
    }
  }

  /// Prompts the system to let the user choose PhaseGuard as the default dialer.
  ///
  /// Returns a map with keys:
  /// - `alreadyDefault` (bool) — was already default before this call
  /// - `requested` (bool) — the dialog was shown
  /// - `granted` (bool) — user accepted (only meaningful when `requested == true`)
  Future<Map<String, dynamic>> requestDefaultDialer() async {
    try {
      final result = await _dialerChannel
          .invokeMapMethod<String, dynamic>('requestDefaultDialer');
      return result ?? {};
    } on PlatformException catch (e) {
      _log('requestDefaultDialer error: ${e.message}');
      return {'error': e.message};
    }
  }

  // ---------------------------------------------------------------------------
  // InCall Service Control (requires being the default dialer)
  // ---------------------------------------------------------------------------

  /// Answers the currently ringing call. Returns `false` if no call is active.
  Future<bool> answerCall() async {
    try {
      final result =
          await _inCallChannel.invokeMethod<bool>('answerCall');
      return result ?? false;
    } on PlatformException catch (e) {
      _log('answerCall error: ${e.message}');
      return false;
    }
  }

  /// Rejects the currently ringing call.
  Future<bool> rejectCall() async {
    try {
      final result =
          await _inCallChannel.invokeMethod<bool>('rejectCall');
      return result ?? false;
    } on PlatformException catch (e) {
      _log('rejectCall error: ${e.message}');
      return false;
    }
  }

  /// Disconnects the active call.
  Future<bool> disconnectCall() async {
    try {
      final result =
          await _inCallChannel.invokeMethod<bool>('disconnectCall');
      return result ?? false;
    } on PlatformException catch (e) {
      _log('disconnectCall error: ${e.message}');
      return false;
    }
  }

  /// Returns `true` if the native InCallService currently has an active call.
  Future<bool> hasActiveCall() async {
    try {
      final result =
          await _inCallChannel.invokeMethod<bool>('hasActiveCall');
      return result ?? false;
    } on PlatformException catch (e) {
      _log('hasActiveCall error: ${e.message}');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _handleNativeCall(MethodCall call) async {
    final args =
        call.arguments != null ? Map<String, dynamic>.from(call.arguments) : <String, dynamic>{};

    switch (call.method) {
      case 'onCallAdded':
        _currentPhoneNumber = args['phoneNumber'] as String? ?? '';
        _currentState = _parseState(args['callState'] as String?);
        _emit('callAdded');
        break;

      case 'onCallRemoved':
        final number = _currentPhoneNumber ?? '';
        _currentPhoneNumber = null;
        _currentState = InCallState.idle;
        _eventController.add(CallEvent(
          type: 'callRemoved',
          phoneNumber: number,
          state: InCallState.idle,
        ));
        break;

      case 'onCallStateChanged':
        _currentPhoneNumber = args['phoneNumber'] as String? ?? _currentPhoneNumber ?? '';
        final rawState = args['state'] as int?;
        _currentState = _parseStateInt(rawState);
        _emit('callStateChanged');
        break;
    }
  }

  void _emit(String type) {
    _eventController.add(CallEvent(
      type: type,
      phoneNumber: _currentPhoneNumber ?? '',
      state: _currentState,
    ));
  }

  /// Parses the string state from [Call.details.state.toString()] (Android API).
  InCallState _parseState(String? stateStr) {
    if (stateStr == null) return InCallState.unknown;
    final s = stateStr.toLowerCase();
    if (s.contains('ringing')) return InCallState.ringing;
    if (s.contains('active')) return InCallState.active;
    if (s.contains('holding')) return InCallState.holding;
    if (s.contains('disconnecting')) return InCallState.disconnecting;
    if (s.contains('disconnected') || s.contains('new')) return InCallState.idle;
    return InCallState.unknown;
  }

  /// Parses the integer state from [Call.STATE_*] constants.
  InCallState _parseStateInt(int? state) {
    switch (state) {
      case 1: // STATE_DIALING
      case 2: // STATE_RINGING
        return InCallState.ringing;
      case 3: // STATE_HOLDING
        return InCallState.holding;
      case 4: // STATE_ACTIVE
        return InCallState.active;
      case 5: // STATE_DISCONNECTED
      case 6: // STATE_SELECT_PHONE_ACCOUNT
      case 7: // STATE_CONNECTING
        return InCallState.idle;
      case 8: // STATE_DISCONNECTING
        return InCallState.disconnecting;
      default:
        return InCallState.unknown;
    }
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[InCallService] $msg');
  }
}
