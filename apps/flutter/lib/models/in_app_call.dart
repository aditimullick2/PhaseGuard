import '../utils/firestore_helpers.dart';

class InAppCall {
  final String callId;
  final String callerId;
  final String calleeId;
  final String callerName;
  final String calleeName;
  final String? callerPic;
  final String? calleePic;
  final String type; // 'audio' or 'video'
  final String status; // 'calling', 'ringing', 'connected', 'ended', 'rejected', 'missed', 'busy'
  final String channelName;
  final DateTime startTime;
  final DateTime? connectedTime;
  final DateTime? endTime;
  final int? durationSeconds;

  const InAppCall({
    required this.callId,
    required this.callerId,
    required this.calleeId,
    required this.callerName,
    required this.calleeName,
    this.callerPic,
    this.calleePic,
    required this.type,
    required this.status,
    required this.channelName,
    required this.startTime,
    this.connectedTime,
    this.endTime,
    this.durationSeconds,
  });

  factory InAppCall.fromMap(Map<String, dynamic> map, String callId) {
    return InAppCall(
      callId: callId,
      callerId: map['callerId'] as String? ?? '',
      calleeId: map['calleeId'] as String? ?? '',
      callerName: map['callerName'] as String? ?? 'Caller',
      calleeName: map['calleeName'] as String? ?? 'Recipient',
      callerPic: map['callerPic'] as String?,
      calleePic: map['calleePic'] as String?,
      type: map['type'] as String? ?? 'audio',
      status: map['status'] as String? ?? 'calling',
      channelName: map['channelName'] as String? ?? callId,
      startTime: parseFirestoreTimestamp(map['startTime']) ?? DateTime.now(),
      connectedTime: parseFirestoreTimestamp(map['connectedTime']),
      endTime: parseFirestoreTimestamp(map['endTime']),
      durationSeconds: map['durationSeconds'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callerId': callerId,
      'calleeId': calleeId,
      'callerName': callerName,
      'calleeName': calleeName,
      'callerPic': callerPic,
      'calleePic': calleePic,
      'type': type,
      'status': status,
      'channelName': channelName,
      'startTime': startTime.millisecondsSinceEpoch,
      'connectedTime': connectedTime?.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'durationSeconds': durationSeconds,
    };
  }

  bool get isActive =>
      status == 'calling' || status == 'ringing' || status == 'connected';

  bool get isEnded =>
      status == 'ended' || status == 'rejected' || status == 'missed' || status == 'busy';
}
