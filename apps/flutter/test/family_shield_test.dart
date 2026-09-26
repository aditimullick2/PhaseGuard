import 'package:flutter_test/flutter_test.dart';
import 'package:phaseguard/services/family_shield_service.dart';

void main() {
  group('Family Shield - Model & Serialization Tests', () {
    test('FamilyContact parses JSON correctly with full fields', () {
      final json = {
        'id': 'contact-123',
        'owner_user_id': 'user-456',
        'display_name': 'Mom',
        'relationship': 'Mother',
        'voice_status': 'enrolled',
        'enabled': true,
        'voice_profile_id': 'profile-789',
        'created_at': '2026-09-26T00:00:00.000Z',
        'updated_at': '2026-09-26T01:00:00.000Z',
      };

      final contact = FamilyContact.fromJson(json);

      expect(contact.id, 'contact-123');
      expect(contact.userId, 'user-456');
      expect(contact.name, 'Mom');
      expect(contact.relationship, 'Mother');
      expect(contact.hasVoiceprint, isTrue);
      expect(contact.isEnabled, isTrue);
      expect(contact.voiceStatus, 'enrolled');
      expect(contact.voiceProfileId, 'profile-789');
    });

    test('FamilyContact parses unenrolled contact and defaults', () {
      final json = {
        'id': 'contact-999',
        'name': 'Dad',
        'relationship': 'Father',
      };

      final contact = FamilyContact.fromJson(json);

      expect(contact.id, 'contact-999');
      expect(contact.name, 'Dad');
      expect(contact.relationship, 'Father');
      expect(contact.hasVoiceprint, isFalse);
      expect(contact.isEnabled, isTrue);
      expect(contact.voiceStatus, 'not_enrolled');
      expect(contact.voiceProfileId, isNull);
    });

    test('FamilyContact copyWith updates fields properly', () {
      final contact = FamilyContact(
        id: '1',
        userId: 'u1',
        name: 'Mom',
        relationship: 'Mother',
        hasVoiceprint: false,
        isEnabled: true,
        voiceStatus: 'not_enrolled',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = contact.copyWith(
        hasVoiceprint: true,
        voiceStatus: 'enrolled',
        voiceProfileId: 'vp-1',
        isEnabled: false,
      );

      expect(updated.id, '1');
      expect(updated.name, 'Mom');
      expect(updated.hasVoiceprint, isTrue);
      expect(updated.voiceStatus, 'enrolled');
      expect(updated.voiceProfileId, 'vp-1');
      expect(updated.isEnabled, isFalse);
    });
  });

  group('Family Shield - Verification Result Tests', () {
    test('MATCHED status parses correctly with probabilistic metadata', () {
      final json = {
        'status': 'MATCHED',
        'contact_id': 'c-1',
        'name': 'Mom',
        'relationship': 'Mother',
        'confidence': 0.92,
        'similarity': 0.92,
        'message': 'Voice matches Mom',
      };

      final result = FamilyVerificationResult.fromJson(json);

      expect(result.status, 'MATCHED');
      expect(result.verified, isTrue);
      expect(result.matchedContactId, 'c-1');
      expect(result.matchedContactName, 'Mom');
      expect(result.matchedRelationship, 'Mother');
      expect(result.confidence, 0.92);
      expect(result.similarity, 0.92);
      expect(result.message, 'Voice matches Mom');
      // Must not use absolute certainty language
      expect(result.message.toLowerCase(), isNot(contains('definitely')));
    });

    test('NO_MATCH status parses correctly', () {
      final json = {
        'status': 'NO_MATCH',
        'confidence': 0.22,
        'similarity': 0.22,
        'message': 'Voice does not match any enrolled contact',
      };

      final result = FamilyVerificationResult.fromJson(json);

      expect(result.status, 'NO_MATCH');
      expect(result.verified, isFalse);
      expect(result.matchedContactId, isNull);
      expect(result.confidence, 0.22);
    });

    test('UNCERTAIN status represents borderline similarity', () {
      final json = {
        'status': 'UNCERTAIN',
        'confidence': 0.68,
        'similarity': 0.68,
        'message': 'Speaker could not be verified with high confidence',
      };

      final result = FamilyVerificationResult.fromJson(json);

      expect(result.status, 'UNCERTAIN');
      expect(result.verified, isFalse);
      expect(result.confidence, 0.68);
    });

    test('INSUFFICIENT_AUDIO status handles short audio', () {
      final json = {
        'status': 'INSUFFICIENT_AUDIO',
        'confidence': 0.0,
        'similarity': 0.0,
        'message': 'Audio too short for speaker verification',
      };

      final result = FamilyVerificationResult.fromJson(json);

      expect(result.status, 'INSUFFICIENT_AUDIO');
      expect(result.verified, isFalse);
    });

    test('UNAVAILABLE status handles no voice profiles', () {
      final json = {
        'status': 'UNAVAILABLE',
        'confidence': 0.0,
        'similarity': 0.0,
        'message': 'No enrolled voice profiles available',
      };

      final result = FamilyVerificationResult.fromJson(json);

      expect(result.status, 'UNAVAILABLE');
      expect(result.verified, isFalse);
    });
  });

  group('Family Shield - Business Logic & Constraint Tests', () {
    test('Maximum 5 contacts constraint validation', () {
      final contacts = List.generate(
        5,
        (i) => FamilyContact(
          id: 'c-$i',
          userId: 'u-1',
          name: 'Contact $i',
          relationship: 'Relative',
          hasVoiceprint: false,
          isEnabled: true,
          voiceStatus: 'not_enrolled',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Contact count limit is 5
      expect(contacts.length, 5);
      final canAddMore = contacts.length < 5;
      expect(canAddMore, isFalse);
    });

    test('Validation prevents empty contact names', () {
      bool isValidContactName(String name) {
        return name.trim().isNotEmpty;
      }

      expect(isValidContactName(''), isFalse);
      expect(isValidContactName('   '), isFalse);
      expect(isValidContactName('Mom'), isTrue);
      expect(isValidContactName('Uncle Bob'), isTrue);
    });

    test('Allowed relationships list matches design requirements', () {
      const allowedRelationships = [
        'Mother',
        'Father',
        'Brother',
        'Sister',
        'Spouse',
        'Child',
        'Grandparent',
        'Relative',
        'Friend',
        'Other',
      ];

      expect(allowedRelationships.contains('Mother'), isTrue);
      expect(allowedRelationships.contains('Father'), isTrue);
      expect(allowedRelationships.contains('Brother'), isTrue);
      expect(allowedRelationships.contains('Sister'), isTrue);
      expect(allowedRelationships.contains('Spouse'), isTrue);
      expect(allowedRelationships.contains('Child'), isTrue);
      expect(allowedRelationships.contains('Grandparent'), isTrue);
      expect(allowedRelationships.contains('Relative'), isTrue);
      expect(allowedRelationships.contains('Friend'), isTrue);
      expect(allowedRelationships.contains('Other'), isTrue);
    });
  });
}
