import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/in_app_call.dart';
import '../models/app_user.dart';

class CallSignalingService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<InAppCall?> listenForIncomingCalls(String currentUserId) {
    debugPrint('[CallSignaling] Listening for incoming calls for user: $currentUserId');
    return _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .map((snapshot) {
      debugPrint('[CallSignaling] Call snapshot size: ${snapshot.docs.length}');
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      debugPrint('[CallSignaling] Incoming call detected: ${doc.id}');
      return InAppCall.fromMap(doc.data(), doc.id);
    });
  }

  Stream<InAppCall?> streamCall(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return InAppCall.fromMap(doc.data()!, doc.id);
    });
  }

  Future<InAppCall> initiateCall({
    required AppUser caller,
    required AppUser callee,
    required String type, // 'audio' or 'video'
  }) async {
    final docRef = _firestore.collection('calls').doc();
    final callId = docRef.id;

    final call = InAppCall(
      callId: callId,
      callerId: caller.uid,
      calleeId: callee.uid,
      callerName: caller.displayName,
      calleeName: callee.displayName,
      callerPic: caller.photoUrl,
      calleePic: callee.photoUrl,
      type: type,
      status: 'calling',
      channelName: callId,
      startTime: DateTime.now(),
    );

    debugPrint('[CallSignaling] Initiating call: caller=${caller.uid}, callee=${callee.uid}, type=$type, callId=$callId');
    await docRef.set(call.toMap());
    debugPrint('[CallSignaling] Call document created successfully');
    return call;
  }

  Future<void> answerCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'connected',
        'connectedTime': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[CallSignaling] Error answering call: $e');
    }
  }

  Future<void> rejectCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'rejected',
        'endTime': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[CallSignaling] Error rejecting call: $e');
    }
  }

  Future<void> endCall(String callId, {int? durationSeconds}) async {
    try {
      final updates = <String, dynamic>{
        'status': 'ended',
        'endTime': DateTime.now().millisecondsSinceEpoch,
      };
      if (durationSeconds != null) {
        updates['durationSeconds'] = durationSeconds;
      }
      await _firestore.collection('calls').doc(callId).update(updates);
    } catch (e) {
      debugPrint('[CallSignaling] Error ending call: $e');
    }
  }

  Stream<List<InAppCall>> getCallHistory(String userId) {
    final controller = StreamController<List<InAppCall>>.broadcast();
    final mergedMap = <String, InAppCall>{};

    StreamSubscription? subCaller;
    StreamSubscription? subCallee;

    void emitSorted() {
      final list = mergedMap.values.toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));
      if (!controller.isClosed) {
        controller.add(list);
      }
    }

    subCaller = _firestore
        .collection('calls')
        .where('callerId', isEqualTo: userId)
        .snapshots()
        .listen((snap) {
      for (final doc in snap.docs) {
        mergedMap[doc.id] = InAppCall.fromMap(doc.data(), doc.id);
      }
      emitSorted();
    }, onError: (_) {});

    subCallee = _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: userId)
        .snapshots()
        .listen((snap) {
      for (final doc in snap.docs) {
        mergedMap[doc.id] = InAppCall.fromMap(doc.data(), doc.id);
      }
      emitSorted();
    }, onError: (_) {});

    controller.onCancel = () {
      subCaller?.cancel();
      subCallee?.cancel();
      controller.close();
    };

    return controller.stream;
  }
}
