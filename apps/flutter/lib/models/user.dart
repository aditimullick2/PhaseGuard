class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? fcmToken;
  final String? voiceProfileVersion;
  final DateTime? voiceProfileCreatedAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.isOnline,
    this.lastSeen,
    this.fcmToken,
    this.voiceProfileVersion,
    this.voiceProfileCreatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSeen']) 
          : null,
      fcmToken: map['fcmToken'],
      voiceProfileVersion: map['voiceProfileVersion'],
      voiceProfileCreatedAt: map['voiceProfileCreatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['voiceProfileCreatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.millisecondsSinceEpoch,
      'fcmToken': fcmToken,
      'voiceProfileVersion': voiceProfileVersion,
      'voiceProfileCreatedAt': voiceProfileCreatedAt?.millisecondsSinceEpoch,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    bool? isOnline,
    DateTime? lastSeen,
    String? fcmToken,
    String? voiceProfileVersion,
    DateTime? voiceProfileCreatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      fcmToken: fcmToken ?? this.fcmToken,
      voiceProfileVersion: voiceProfileVersion ?? this.voiceProfileVersion,
      voiceProfileCreatedAt: voiceProfileCreatedAt ?? this.voiceProfileCreatedAt,
    );
  }
}
