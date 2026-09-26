import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../components/app_theme.dart';
import '../components/app_button.dart';
import '../services/family_shield_service.dart';

/// Voice enrollment screen for Family Shield contacts.
/// Follows the same 15-second recording pattern as Voice ID setup.
class FamilyVoiceEnrollmentScreen extends StatefulWidget {
  final FamilyContact contact;

  const FamilyVoiceEnrollmentScreen({super.key, required this.contact});

  @override
  State<FamilyVoiceEnrollmentScreen> createState() =>
      _FamilyVoiceEnrollmentScreenState();
}

class _FamilyVoiceEnrollmentScreenState
    extends State<FamilyVoiceEnrollmentScreen> {
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _secondsLeft = 15;
  Timer? _timer;
  bool _isEnrollmentComplete = false;
  String? _recordingPath;
  bool _isUploading = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      debugPrint('[FamilyShield] Starting voice enrollment recording...');
      
      // Check permission
      if (!await _audioRecorder.hasPermission()) {
        debugPrint('[FamilyShield] Microphone permission not granted');
        final permissionGranted = await _audioRecorder.hasPermission();
        if (!permissionGranted) {
          setState(() => _error = 'Microphone permission is required');
          return;
        }
      }

      // Get proper temp directory using path_provider
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/family_voice_${widget.contact.id}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      debugPrint('[FamilyShield] Recording path: $path');

      // Check if directory exists
      final dir = Directory(directory.path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        debugPrint('[FamilyShield] Created directory: ${directory.path}');
      }

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
        path: path,
      );
      debugPrint('[FamilyShield] Recording started');

      setState(() {
        _isRecording = true;
        _secondsLeft = 15;
        _isEnrollmentComplete = false;
        _error = null;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        setState(() {
          if (_secondsLeft > 0) {
            _secondsLeft--;
          }
        });

        if (_secondsLeft == 0) {
          timer.cancel();
          await _stopRecording();
        }
      });
    } catch (e) {
      debugPrint('[FamilyShield] Error starting record: $e');
      setState(() => _error = 'Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    debugPrint('[FamilyShield] Stopping recording...');
    final path = await _audioRecorder.stop();
    debugPrint('[FamilyShield] Recording stopped. Path: $path');
    
    setState(() {
      _isRecording = false;
      _isEnrollmentComplete = true;
      _recordingPath = path;
    });
  }

  Future<void> _uploadEnrollment() async {
    if (_recordingPath == null) {
      setState(() => _error = 'No recording available');
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final file = File(_recordingPath!);
      if (!await file.exists()) {
        throw Exception('Recording file not found');
      }

      final service = FamilyShieldService();
      final result = await service.enrollVoice(
        contactId: widget.contact.id,
        audioFile: file,
      );

      debugPrint('[FamilyShield] Voice enrollment successful: $result');

      // Clean up temporary file
      try {
        await file.delete();
        debugPrint('[FamilyShield] Temporary recording deleted');
      } catch (e) {
        debugPrint('[FamilyShield] Failed to delete temp file: $e');
      }

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      debugPrint('[FamilyShield] Voice enrollment failed: $e');
      setState(() {
        _isUploading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _cancelEnrollment() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              color: AppColors.primaryText, size: 20),
          onPressed: _cancelEnrollment,
        ),
        title: Text('Enroll Voice', style: AppTextStyles.titleSmall),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Contact info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          widget.contact.name.isNotEmpty
                              ? widget.contact.name[0].toUpperCase()
                              : '?',
                          style: AppTextStyles.titleSmall,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.contact.name,
                              style: AppTextStyles.labelMedium),
                          const SizedBox(height: 2),
                          Text(
                            widget.contact.relationship.isNotEmpty
                                ? widget.contact.relationship
                                : 'Trusted Contact',
                            style: AppTextStyles.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Instructions
              if (!_isEnrollmentComplete) ...[
                Text(
                  'Record a voice sample',
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Ask ${widget.contact.name} to read the following phrase clearly:',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '"My voice is my password. Protect me from deepfakes and scams."',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),

                if (_isRecording)
                  Column(
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text('$_secondsLeft seconds remaining...',
                          style: AppTextStyles.labelMedium),
                    ],
                  )
                else
                  AppButton(
                    content: 'Start Recording (15s)',
                    fullWidth: true,
                    onTap: _startRecording,
                  ),
              ] else ...[
                const Icon(Icons.check_circle_rounded,
                    size: 64, color: AppColors.success),
                const SizedBox(height: 16),
                Text(
                  'Voice sample captured',
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Review and upload to complete enrollment',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                if (_isUploading)
                  const CircularProgressIndicator(color: AppColors.primary)
                else
                  AppButton(
                    content: 'Upload & Enroll',
                    fullWidth: true,
                    onTap: _uploadEnrollment,
                  ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Cancel button
              if (!_isEnrollmentComplete || !_isUploading)
                TextButton(
                  onPressed: _cancelEnrollment,
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.secondaryText)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
