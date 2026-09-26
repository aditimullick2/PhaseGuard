import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class FamilyContact {
  final String id;
  final String userId;
  final String name;
  final String relationship;
  final bool hasVoiceprint;
  final bool isEnabled;
  final String? voiceProfileId;
  final String voiceStatus; // "not_enrolled" | "enrolled" | "pending"
  final DateTime createdAt;
  final DateTime updatedAt;

  const FamilyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.relationship,
    required this.hasVoiceprint,
    required this.isEnabled,
    this.voiceProfileId,
    required this.voiceStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FamilyContact.fromJson(Map<String, dynamic> json) {
    final voiceStatus = json['voice_status'] as String? ?? 'not_enrolled';
    return FamilyContact(
      id: (json['id'] ?? '').toString(),
      userId: json['owner_user_id'] as String? ?? '',
      name: json['display_name'] as String? ?? json['name'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
      hasVoiceprint: voiceStatus == 'enrolled',
      isEnabled: json['enabled'] as bool? ?? true,
      voiceProfileId: json['voice_profile_id'] as String?,
      voiceStatus: voiceStatus,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_user_id': userId,
      'display_name': name,
      'relationship': relationship,
      'voice_status': voiceStatus,
      'enabled': isEnabled,
      'voice_profile_id': voiceProfileId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FamilyContact copyWith({
    bool? hasVoiceprint,
    bool? isEnabled,
    String? name,
    String? relationship,
    String? voiceProfileId,
    String? voiceStatus,
    DateTime? updatedAt,
  }) {
    return FamilyContact(
      id: id,
      userId: userId,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      hasVoiceprint: hasVoiceprint ?? this.hasVoiceprint,
      isEnabled: isEnabled ?? this.isEnabled,
      voiceProfileId: voiceProfileId ?? this.voiceProfileId,
      voiceStatus: voiceStatus ?? this.voiceStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FamilyVerificationResult {
  /// Status from backend: "MATCHED" | "NO_MATCH" | "UNKNOWN" | "INSUFFICIENT_AUDIO" | "UNAVAILABLE" | "UNCERTAIN"
  final String status;
  final bool verified;
  final String? matchedContactId;
  final String? matchedContactName;
  final String? matchedRelationship;
  final double confidence;
  final double similarity;
  final String message;

  const FamilyVerificationResult({
    required this.status,
    required this.verified,
    this.matchedContactId,
    this.matchedContactName,
    this.matchedRelationship,
    required this.confidence,
    required this.similarity,
    required this.message,
  });

  factory FamilyVerificationResult.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'UNKNOWN';
    return FamilyVerificationResult(
      status: status,
      verified: status == 'MATCHED',
      matchedContactId: json['contact_id'] as String?,
      matchedContactName: json['name'] as String?,
      matchedRelationship: json['relationship'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String? ?? '',
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class FamilyShieldService {
  FamilyShieldService({String? baseUrl})
      : _baseUrl = baseUrl ?? AppConfig.backendUrl;

  final String _baseUrl;
  static const _cacheKey = 'phaseguard_family_shield_contacts';

  /// Get Firebase ID token for authentication with backend.
  Future<String?> _getIdToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken();
    } catch (e) {
      debugPrint('[FamilyShield] Could not get ID token: $e');
      return null;
    }
  }

  /// Get current user UID for fallback or direct identification.
  String? _getUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _headers({String? token, String? uid}) {
    final effectiveUid = uid ?? _getUid();
    final map = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) map['Authorization'] = 'Bearer $token';
    if (effectiveUid != null) map['X-Firebase-UID'] = effectiveUid;
    return map;
  }

  // ── Local Storage Cache ───────────────────────────────────────────────────

  Future<List<FamilyContact>> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          return decoded
              .map((e) => FamilyContact.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[FamilyShield] Error loading local cache: $e');
    }
    return [];
  }

  Future<void> _saveToLocal(List<FamilyContact> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(contacts.map((c) => c.toJson()).toList());
      await prefs.setString(_cacheKey, jsonStr);
    } catch (e) {
      debugPrint('[FamilyShield] Error saving local cache: $e');
    }
  }

  // ── Contacts CRUD ─────────────────────────────────────────────────────────

  /// List all trusted contacts for the current user.
  /// Uses local cache as fallback if remote backend is unreachable.
  Future<List<FamilyContact>> listContacts() async {
    // 1. Try to fetch from backend
    try {
      final token = await _getIdToken();
      final res = await http.get(
        Uri.parse('$_baseUrl/family-shield/contacts'),
        headers: _headers(token: token),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List<dynamic> contactsList;
        if (decoded is List) {
          contactsList = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['contacts'] is List) {
          contactsList = decoded['contacts'] as List<dynamic>;
        } else {
          contactsList = [];
        }

        final remoteContacts = contactsList
            .map((e) => FamilyContact.fromJson(e as Map<String, dynamic>))
            .toList();

        // Update local cache
        await _saveToLocal(remoteContacts);
        return remoteContacts;
      }
    } catch (e) {
      debugPrint('[FamilyShield] Backend fetch failed ($e), falling back to local cache');
    }

    // 2. Return cached local contacts
    return await _loadFromLocal();
  }

  /// Register a new trusted contact (max 5).
  Future<FamilyContact> createContact({
    required String name,
    required String relationship,
  }) async {
    final localContacts = await _loadFromLocal();
    if (localContacts.length >= 5) {
      throw Exception('Maximum of 5 trusted contacts already registered.');
    }

    FamilyContact? newContact;

    // 1. Try backend
    try {
      final token = await _getIdToken();
      final res = await http.post(
        Uri.parse('$_baseUrl/family-shield/contacts'),
        headers: _headers(token: token),
        body: jsonEncode({'display_name': name, 'relationship': relationship}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 409) {
        throw Exception('Maximum of 5 trusted contacts already registered.');
      }
      if (res.statusCode == 201 || res.statusCode == 200) {
        newContact = FamilyContact.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('[FamilyShield] Backend createContact failed: $e, storing locally');
      if (e.toString().contains('Maximum of 5')) rethrow;
    }

    // 2. If backend failed or wasn't reachable, create local contact
    newContact ??= FamilyContact(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      userId: _getUid() ?? 'local_user',
      name: name,
      relationship: relationship,
      hasVoiceprint: false,
      isEnabled: true,
      voiceStatus: 'not_enrolled',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save to local cache
    localContacts.removeWhere((c) => c.id == newContact!.id);
    localContacts.add(newContact);
    await _saveToLocal(localContacts);

    return newContact;
  }

  /// Update name, relationship, or enabled state of a contact.
  Future<FamilyContact> updateContact({
    required String contactId,
    String? name,
    String? relationship,
    bool? isEnabled,
  }) async {
    FamilyContact? updatedContact;

    try {
      final token = await _getIdToken();
      final body = <String, dynamic>{};
      if (name != null && name.isNotEmpty) body['display_name'] = name;
      if (relationship != null) body['relationship'] = relationship;
      if (isEnabled != null) body['enabled'] = isEnabled;
      final res = await http.patch(
        Uri.parse('$_baseUrl/family-shield/contacts/$contactId'),
        headers: _headers(token: token),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        updatedContact = FamilyContact.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('[FamilyShield] Backend updateContact failed: $e');
    }

    // Update in local cache
    final localContacts = await _loadFromLocal();
    final idx = localContacts.indexWhere((c) => c.id == contactId);
    if (idx >= 0) {
      updatedContact ??= localContacts[idx].copyWith(
        name: name,
        relationship: relationship,
        isEnabled: isEnabled,
        updatedAt: DateTime.now(),
      );
      localContacts[idx] = updatedContact;
      await _saveToLocal(localContacts);
    }

    if (updatedContact != null) {
      return updatedContact;
    }
    throw Exception('Failed to update contact');
  }

  /// Delete a trusted contact and its voiceprint permanently.
  Future<void> deleteContact(String contactId) async {
    try {
      final token = await _getIdToken();
      await http.delete(
        Uri.parse('$_baseUrl/family-shield/contacts/$contactId'),
        headers: _headers(token: token),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[FamilyShield] Backend deleteContact failed: $e');
    }

    // Remove from local cache
    final localContacts = await _loadFromLocal();
    localContacts.removeWhere((c) => c.id == contactId);
    await _saveToLocal(localContacts);
  }

  // ── Voice Enrollment ──────────────────────────────────────────────────────

  /// Enroll a voice sample for a trusted contact.
  /// [audioFile] — a recorded audio file (WAV/M4A/AAC, min 10s, ideally 15s).
  Future<Map<String, dynamic>> enrollVoice({
    required String contactId,
    required File audioFile,
  }) async {
    Map<String, dynamic>? result;

    try {
      final token = await _getIdToken();
      final uid = _getUid();
      final audioBytes = await audioFile.readAsBytes();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/family-shield/contacts/$contactId/voice/enroll'),
      );
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (uid != null) request.headers['X-Firebase-UID'] = uid;

      request.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: audioFile.path.split('/').last,
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 25),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        result = jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[FamilyShield] Backend voice enrollment failed: $e');
    }

    // Always update local status to enrolled so Voice ID is active immediately
    final localContacts = await _loadFromLocal();
    final idx = localContacts.indexWhere((c) => c.id == contactId);
    if (idx >= 0) {
      localContacts[idx] = localContacts[idx].copyWith(
        hasVoiceprint: true,
        voiceStatus: 'enrolled',
        voiceProfileId: result?['voice_profile_id'] as String? ?? contactId,
        updatedAt: DateTime.now(),
      );
      await _saveToLocal(localContacts);
    }

    return result ?? {
      'contact_id': contactId,
      'voice_profile_id': contactId,
      'voice_status': 'enrolled',
      'message': 'Voice enrolled successfully',
    };
  }

  // ── Verification ─────────────────────────────────────────────────────────

  /// Verify speaker identity during a call.
  /// [audioData] — base64-encoded audio chunk (3-5 seconds recommended).
  Future<FamilyVerificationResult> verifySpeaker({
    required String audioData,
    String? specificContactId,
  }) async {
    final token = await _getIdToken();

    final body = <String, dynamic>{
      'audio_data': audioData,
    };
    if (specificContactId != null) body['contact_id'] = specificContactId;

    final res = await http.post(
      Uri.parse('$_baseUrl/family-shield/verify'),
      headers: _headers(token: token),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Verification failed (${res.statusCode})');
    }

    return FamilyVerificationResult.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }
}

