import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class PushService {
  static const _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
  static const _projectId = 'callconnect-59d06'; // From your JSON

  /// Fetches an OAuth 2.0 token using the bundled service account JSON.
  Future<String?> _getAccessToken() async {
    try {
      final jsonString = await rootBundle.loadString('assets/service_account.json');
      final accountCredentials = ServiceAccountCredentials.fromJson(jsonString);
      
      final client = await clientViaServiceAccount(accountCredentials, _scopes);
      final accessToken = client.credentials.accessToken.data;
      client.close();
      return accessToken;
    } catch (e) {
      debugPrint('[PushService] Error getting access token: $e');
      return null;
    }
  }

  /// Sends a high-priority FCM v1 push notification to the target device.
  Future<void> sendIncomingCallNotification({
    required String targetFcmToken,
    required String callId,
    required String callerId,
    required String callerName,
    required String calleeId,
    required String callType, // 'audio' or 'video'
    required String channelName,
  }) async {
    final token = await _getAccessToken();
    if (token == null) {
      debugPrint('[PushService] Failed to get OAuth token. Push not sent.');
      return;
    }

    final url = Uri.parse('https://fcm.googleapis.com/v1/projects/$_projectId/messages:send');

    final payload = {
      'message': {
        'token': targetFcmToken,
        'data': {
          'callId': callId,
          'callerId': callerId,
          'callerName': callerName,
          'calleeId': calleeId,
          'callType': callType,
          'channelName': channelName,
          'type': 'incoming_call',
        },
        'android': {
          'priority': 'HIGH',
          'ttl': '30s',
        },
        'apns': {
          'headers': {
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
          'payload': {
            'aps': {
              'sound': 'default',
              'badge': 1,
            },
          },
        },
      }
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint('[PushService] Push notification sent successfully to FCM!');
      } else {
        debugPrint('[PushService] FCM API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[PushService] HTTP POST error: $e');
    }
  }
}
