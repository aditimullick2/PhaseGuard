import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import 'home_screen.dart';
import '../components/app_theme.dart';
import '../components/app_button.dart';
import '../components/animated_gradient_bg.dart';

class VoiceIdSetupScreen extends ConsumerStatefulWidget {
  const VoiceIdSetupScreen({super.key});

  @override
  ConsumerState<VoiceIdSetupScreen> createState() => _VoiceIdSetupScreenState();
}

class _VoiceIdSetupScreenState extends ConsumerState<VoiceIdSetupScreen> {
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _secondsLeft = 15;
  Timer? _timer;
  String? _voiceIdPath;
  bool _isSetupComplete = false;

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final prefs = await SharedPreferences.getInstance();
        final path = '${prefs.getString('cache_dir') ?? ''}/voice_id.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _secondsLeft = 15;
          _isSetupComplete = false;
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
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _voiceIdPath = path;
      _isSetupComplete = true;
    });

    if (path != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_voice_id_path', path);
      
      final authService = ref.read(authServiceProvider);
      final currentUser = authService.currentUser;
      if (currentUser != null) {
        final userService = ref.read(userServiceProvider);
        await userService.updateVoiceProfileStatus(currentUser.uid, 'v1');
      }
    }
  }

  void _finishSetup() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedGradientBg(
              preset: GradientPreset.hero,
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic_rounded, size: 64, color: AppColors.primary),
                    const SizedBox(height: 24),
                    Text(
                      'Voice ID Setup',
                      style: AppTextStyles.titleLarge.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isSetupComplete 
                        ? 'Your Voice ID is securely saved.'
                        : 'Please read the following phrase clearly to register your unique Voice ID for deepfake protection.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 32),
                    
                    if (!_isSetupComplete) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '"My voice is my password. Protect me from deepfakes and scams."',
                          style: AppTextStyles.bodyLarge.copyWith(fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 48),

                      if (_isRecording)
                        Column(
                          children: [
                            const CircularProgressIndicator(color: AppColors.primary),
                            const SizedBox(height: 16),
                            Text('$_secondsLeft seconds remaining...', style: AppTextStyles.labelMedium),
                          ],
                        )
                      else
                        AppButton(
                          content: 'Start Recording (15s)',
                          fullWidth: true,
                          onTap: _startRecording,
                        ),
                    ] else ...[
                      const Icon(Icons.check_circle_rounded, size: 64, color: AppColors.success),
                      const SizedBox(height: 32),
                      AppButton(
                        content: 'Continue to ConnectCall',
                        fullWidth: true,
                        onTap: _finishSetup,
                      ),
                    ],
                    
                    if (!_isRecording && !_isSetupComplete) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _finishSetup,
                        child: const Text('Skip for now', style: TextStyle(color: AppColors.secondaryText)),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
