import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper to convert Firestore timestamps to DateTime
/// Handles Timestamp, int (milliseconds), String, and null
DateTime? parseFirestoreTimestamp(dynamic value) {
  if (value == null) return null;
  
  if (value is Timestamp) {
    return value.toDate();
  }
  
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return DateTime.fromMillisecondsSinceEpoch(parsed);
    }
  }
  
  return null;
}
