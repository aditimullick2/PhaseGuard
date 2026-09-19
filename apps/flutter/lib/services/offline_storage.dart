import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline storage for pending escalations and call metadata.
/// When backend is unavailable, store state locally and sync when reconnected.
class OfflineStorage {
  static const String _pendingEscalationsKey = 'pending_escalations';
  static const String _callMetadataKey = 'call_metadata';
  static const String _offlineScoresKey = 'offline_scores';
  static const String _lastSyncKey = 'last_backend_sync';

  final SharedPreferences _prefs;

  OfflineStorage(this._prefs);

  /// Factory constructor for easy initialization
  static Future<OfflineStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return OfflineStorage(prefs);
  }

  /// Store a pending escalation (draft or confirm) for later sync
  Future<void> storePendingEscalation(String callId, {
    required String type, // 'draft', 'confirm', 'cybercell'
    required Map<String, dynamic> payload,
    required DateTime createdAt,
  }) async {
    final escalations = getPendingEscalations();
    escalations.add({
      'callId': callId,
      'type': type,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'synced': false,
    });
    await _prefs.setString(
      _pendingEscalationsKey,
      jsonEncode(escalations),
    );
  }

  /// Get all pending escalations not yet synced to backend
  List<Map<String, dynamic>> getPendingEscalations() {
    final json = _prefs.getString(_pendingEscalationsKey);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Mark escalation as synced
  Future<void> markEscalationSynced(String callId, String type) async {
    final escalations = getPendingEscalations();
    for (final e in escalations) {
      if (e['callId'] == callId && e['type'] == type) {
        e['synced'] = true;
      }
    }
    await _prefs.setString(
      _pendingEscalationsKey,
      jsonEncode(escalations),
    );
  }

  /// Store offline call metadata (transcript, scores, verdict)
  Future<void> storeCallMetadata(String callId, {
    required String transcript,
    required double pdiScore,
    required Map<String, dynamic> offlineVerdict,
  }) async {
    final metadata = {
      'callId': callId,
      'transcript': transcript,
      'pdiScore': pdiScore,
      'offlineVerdict': offlineVerdict,
      'storedAt': DateTime.now().toIso8601String(),
    };
    await _prefs.setString(
      '$_callMetadataKey:$callId',
      jsonEncode(metadata),
    );
  }

  /// Retrieve offline call metadata
  Map<String, dynamic>? getCallMetadata(String callId) {
    final json = _prefs.getString('$_callMetadataKey:$callId');
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Store offline DSP scores for later comparison with backend
  Future<void> storeOfflineScore(String callId, {
    required double pdiScore,
    required double tremorEnergy,
    required bool isSynthetic,
  }) async {
    final scores = {
      'callId': callId,
      'pdiScore': pdiScore,
      'tremorEnergy': tremorEnergy,
      'isSynthetic': isSynthetic,
      'recordedAt': DateTime.now().toIso8601String(),
    };
    await _prefs.setString(
      '$_offlineScoresKey:$callId',
      jsonEncode(scores),
    );
  }

  /// Get offline scores for a call
  Map<String, dynamic>? getOfflineScore(String callId) {
    final json = _prefs.getString('$_offlineScoresKey:$callId');
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Record last successful backend sync
  Future<void> recordSync() async {
    await _prefs.setString(
      _lastSyncKey,
      DateTime.now().toIso8601String(),
    );
  }

  /// Get timestamp of last sync (null if never synced)
  DateTime? getLastSync() {
    final json = _prefs.getString(_lastSyncKey);
    if (json == null) return null;
    try {
      return DateTime.parse(json);
    } catch (_) {
      return null;
    }
  }

  /// Clear all offline data for a specific call
  Future<void> clearCallData(String callId) async {
    await _prefs.remove('$_callMetadataKey:$callId');
    await _prefs.remove('$_offlineScoresKey:$callId');
  }

  /// Clear all offline storage
  Future<void> clearAll() async {
    await _prefs.remove(_pendingEscalationsKey);
    await _prefs.remove(_lastSyncKey);
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_callMetadataKey) || key.startsWith(_offlineScoresKey)) {
        await _prefs.remove(key);
      }
    }
  }
}
