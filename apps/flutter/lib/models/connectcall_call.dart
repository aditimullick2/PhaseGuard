class CallModel {
  final String callId;
  final String callerId;
  final String calleeId;
  final String callerName;
  final String calleeName;
  final String? callerPic;
  final String? calleePic;
  final String type; // "audio" or "video"
  final String status; // "calling", "ringing", "connected", "ended", "rejected", "missed", "busy", "failed"
  final String agoraChannelName;
  final DateTime startTime;
  final DateTime? connectedTime;
  final DateTime? endTime;
  final int? duration; // in seconds

  CallModel({
    required this.callId,
    required this.callerId,
    required this.calleeId,
    required this.callerName,
    required this.calleeName,
    this.callerPic,
    this.calleePic,
    required this.type,
    required this.status,
    required this.agoraChannelName,
    required this.startTime,
    this.connectedTime,
    this.endTime,
    this.duration,
  });

  factory CallModel.fromMap(Map<String, dynamic> map, String callId) {
    return CallModel(
      callId: callId,
      callerId: map['callerId'] ?? '',
      calleeId: map['calleeId'] ?? '',
      callerName: map['callerName'] ?? '',
      calleeName: map['calleeName'] ?? '',
      callerPic: map['callerPic'],
      calleePic: map['calleePic'],
      type: map['type'] ?? 'audio',
      status: map['status'] ?? 'calling',
      agoraChannelName: map['agoraChannelName'] ?? '',
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime']),
      connectedTime: map['connectedTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['connectedTime']) 
          : null,
      endTime: map['endTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime']) 
          : null,
      duration: map['duration'],
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
      'agoraChannelName': agoraChannelName,
      'startTime': startTime.millisecondsSinceEpoch,
      'connectedTime': connectedTime?.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'duration': duration,
    };
  }

  CallModel copyWith({
    String? callId,
    String? callerId,
    String? calleeId,
    String? callerName,
    String? calleeName,
    String? callerPic,
    String? calleePic,
    String? type,
    String? status,
    String? agoraChannelName,
    DateTime? startTime,
    DateTime? connectedTime,
    DateTime? endTime,
    int? duration,
  }) {
    return CallModel(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      calleeId: calleeId ?? this.calleeId,
      callerName: callerName ?? this.callerName,
      calleeName: calleeName ?? this.calleeName,
      callerPic: callerPic ?? this.callerPic,
      calleePic: calleePic ?? this.calleePic,
      type: type ?? this.type,
      status: status ?? this.status,
      agoraChannelName: agoraChannelName ?? this.agoraChannelName,
      startTime: startTime ?? this.startTime,
      connectedTime: connectedTime ?? this.connectedTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
    );
  }

  bool get isActive => status == 'connected' || status == 'calling' || status == 'ringing';
  bool get isEnded => status == 'ended' || status == 'rejected' || status == 'missed' || status == 'busy' || status == 'failed';
}
