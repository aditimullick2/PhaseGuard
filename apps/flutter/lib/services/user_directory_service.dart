import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';

class UserDirectoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<AppUser>> streamUsers({required String currentUserId}) {
    return _firestore.collection('users').snapshots().map((snapshot) {
      debugPrint('[UserDirectory] Query returned ${snapshot.docs.length} documents');
      
      try {
        final users = snapshot.docs
            .where((doc) => doc.id != currentUserId)
            .map((doc) {
              try {
                return AppUser.fromMap(doc.data(), doc.id);
              } catch (e) {
                debugPrint('[UserDirectory] Error parsing user ${doc.id}: $e');
                return null;
              }
            })
            .whereType<AppUser>()
            .toList();
        
        debugPrint('[UserDirectory] Successfully parsed ${users.length} users');
        
        // Update online status based on lastSeen (2 minutes threshold)
        final now = DateTime.now();
        final onlineThreshold = now.subtract(const Duration(minutes: 2));
        
        debugPrint('[UserDirectory] Current time: $now, Online threshold: $onlineThreshold');
        
        for (final user in users) {
          final isActuallyOnline = user.lastSeen.isAfter(onlineThreshold);
          final timeDiff = now.difference(user.lastSeen);
          debugPrint('[UserDirectory] User ${user.displayName}: lastSeen=${user.lastSeen}, timeDiff=${timeDiff.inSeconds}s, isOnline=$isActuallyOnline');
        }
        
        // Sort: online first, then by name
        users.sort((a, b) {
          final aOnline = a.lastSeen.isAfter(onlineThreshold);
          final bOnline = b.lastSeen.isAfter(onlineThreshold);
          
          if (aOnline && !bOnline) return -1;
          if (!aOnline && bOnline) return 1;
          return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        });
        
        return users;
      } catch (e) {
        debugPrint('[UserDirectory] Error processing users: $e');
        return <AppUser>[];
      }
    });
  }

  Future<AppUser?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return AppUser.fromMap(doc.data()!, uid);
      }
    } catch (e) {
      debugPrint('[UserDirectory] Error getting user $uid: $e');
    }
    return null;
  }
}
