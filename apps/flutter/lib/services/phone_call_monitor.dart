import 'package:flutter/services.dart';

/// Native phone-state events (Android Telephony / iOS CallKit).
class PhoneCallEvent {
  const PhoneCallEvent({required this.state, this.number});

  /// idle | ringing | offhook
  final String state;
  final String? number;

  factory PhoneCallEvent.fromMap(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    final number = map['number'] as String?;
    return PhoneCallEvent(
      state: map['state'] as String? ?? 'idle',
      number: (number == null || number.isEmpty) ? null : number,
    );
  }

  bool get isIncoming => state == 'ringing' || state == 'offhook';
}

class PhoneCallMonitor {
  static const _events = EventChannel('phaseguard/phone_state');
  static const _methods = MethodChannel('phaseguard/phone_control');

  static Stream<PhoneCallEvent> get events =>
      _events.receiveBroadcastStream().map(PhoneCallEvent.fromMap);

  static Future<void> start() async {
    await _methods.invokeMethod<void>('startMonitor');
  }

  static Future<void> stop() async {
    await _methods.invokeMethod<void>('stopMonitor');
  }
}
