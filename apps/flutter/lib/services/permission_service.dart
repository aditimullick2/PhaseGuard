import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

enum CallPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
}

class PermissionService {
  /// Request microphone (and optionally camera) for a call.
  /// Returns [CallPermissionStatus] — never throws.
  Future<CallPermissionStatus> requestCallPermissions({
    bool requireCamera = false,
  }) async {
    final micStatus = await Permission.microphone.request();
    if (micStatus.isPermanentlyDenied) {
      return CallPermissionStatus.permanentlyDenied;
    }
    if (!micStatus.isGranted) {
      return CallPermissionStatus.denied;
    }

    if (requireCamera) {
      final camStatus = await Permission.camera.request();
      if (camStatus.isPermanentlyDenied) {
        return CallPermissionStatus.permanentlyDenied;
      }
      if (!camStatus.isGranted) {
        return CallPermissionStatus.denied;
      }
    }

    return CallPermissionStatus.granted;
  }

  Future<bool> isMicrophoneGranted() async =>
      (await Permission.microphone.status).isGranted;

  Future<bool> isCameraGranted() async =>
      (await Permission.camera.status).isGranted;

  /// Show a dialog explaining why a permission is needed.
  static Future<void> showPermissionDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onTryAgain,
    bool showOpenSettings = false,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (showOpenSettings)
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            )
          else
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                onTryAgain();
              },
              child: const Text('Try Again'),
            ),
        ],
      ),
    );
  }
}
