import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream all users except the current user.
  /// Users are sorted: online first, then by last seen descending.
  Stream<List<UserModel>> getUsers(String currentUserId) {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snapshot) {
      final users = snapshot.docs
          .where((doc) => doc.id != currentUserId)
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();

      // Sort: online users first, then by last seen (most recent first)
      users.sort((a, b) {
        if (a.isOnline && !b.isOnline) return -1;
        if (!a.isOnline && b.isOnline) return 1;
        if (a.lastSeen != null && b.lastSeen != null) {
          return b.lastSeen!.compareTo(a.lastSeen!);
        }
        return a.name.compareTo(b.name);
      });

      return users;
    }).handleError((error) {
      return <UserModel>[]; // Return empty list on permission-denied or other errors
    });
  }

  /// Filter users by name (client-side, case-insensitive, substring match).
  List<UserModel> filterUsersByName(List<UserModel> users, String query) {
    if (query.trim().isEmpty) return users;
    final lower = query.toLowerCase();
    return users
        .where((u) => u.name.toLowerCase().contains(lower))
        .toList();
  }

  /// Set online/offline status and update lastSeen.
  Future<void> setUserOnline(String userId, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {
      // Non-fatal — presence failure should not crash the app
    }
  }

  /// Fetch a user by ID (one-shot).
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    } catch (_) {
      return null;
    }
  }

  /// Real-time stream for a single user document.
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    }).handleError((error) {
      return null; // Return null on permission-denied or other errors
    });
  }

  /// Update FCM token for a user.
  Future<void> updateFcmToken(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
      });
    } catch (_) {
      // Non-fatal
    }
  }

  /// Update profile photo (base64).
  Future<void> updateProfilePhoto(String userId, String base64Image) async {
    await _firestore.collection('users').doc(userId).update({
      'photoUrl': base64Image,
    });
  }
}
