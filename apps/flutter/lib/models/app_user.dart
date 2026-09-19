import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

class AppUser {
  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final bool isOnline;
  final DateTime lastSeen;

  const AppUser({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
    this.isOnline = false,
    required this.lastSeen,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      displayName: map['displayName'] as String? ?? 'Agent ${uid.substring(0, uid.length.clamp(0, 4))}',
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      isOnline: map['isOnline'] as bool? ?? false,
      lastSeen: parseFirestoreTimestamp(map['lastSeen']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    };
  }

  AppUser copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
